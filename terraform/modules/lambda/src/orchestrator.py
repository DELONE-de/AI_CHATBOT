import json
import os
import time
import uuid
import boto3
import logging
from botocore.exceptions import ClientError

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS Clients
lex_client = boto3.client('lexv2-runtime')
dynamodb = boto3.resource('dynamodb')

# Environment Variables
LEX_BOT_ID = os.environ['LEX_BOT_ID']
LEX_BOT_ALIAS_ID = os.environ['LEX_BOT_ALIAS_ID']
DYNAMODB_TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
LOCALE_ID = 'en_US'

table = dynamodb.Table(DYNAMODB_TABLE_NAME)

def lambda_handler(event, context):
    """
    Orchestrates conversation: API GW -> Lambda -> Lex -> DynamoDB -> API GW
    """
    try:
        logger.info("Received event", extra={"event": event})
        
        # 1. Parse Input
        body = json.loads(event.get('body', '{}'))
        user_message = body.get('message')
        
        # 2. Session Management
        # Clients should send a sessionId to maintain context. If null, generate one.
        session_id = body.get('sessionId', str(uuid.uuid4()))
        
        # Client-side distinct chat ID (optional, for UI grouping)
        chat_id = body.get('chatId', str(uuid.uuid4()))

        if not user_message:
            return build_response(400, {"error": "Message field is required"})

        # 3. Call Amazon Lex V2
        # Lex handles the logic: It will either match an Intent or fallback to Bedrock KB
        lex_response = lex_client.recognize_text(
            botId=LEX_BOT_ID,
            botAliasId=LEX_BOT_ALIAS_ID,
            localeId=LOCALE_ID,
            sessionId=session_id,
            text=user_message
        )
        
        logger.info("Lex Response", extra={"response": lex_response})

        # 4. Extract Bot Response
        # Lex returns an array of messages. We concatenate them for simplicity.
        messages = lex_response.get('messages', [])
        bot_text_response = " ".join([m['content'] for m in messages if m['contentType'] == 'PlainText'])
        
        # Identify Intent (Standard intent or Fallback/RAG)
        intent_name = lex_response.get('sessionState', {}).get('intent', {}).get('name', 'Unknown')
        
        # 5. Persist to DynamoDB (Async patterns can be used here, but synchronous for data consistency)
        timestamp = int(time.time())
        try:
            table.put_item(
                Item={
                    'sessionId': session_id,           # Partition Key
                    'timestamp': timestamp,            # Sort Key
                    'chatId': chat_id,
                    'userMessage': user_message,
                    'botResponse': bot_text_response,
                    'intentName': intent_name,
                    'ttl': timestamp + (86400 * 90)    # 90 Day Retention
                }
            )
        except ClientError as e:
            logger.error(f"Failed to persist chat history: {e}")
            # We do not fail the request if logging fails, but we log the error.

        # 6. Return Response to Client
        return build_response(200, {
            "sessionId": session_id,
            "chatId": chat_id,
            "message": bot_text_response,
            "intent": intent_name
        })

    except Exception as e:
        logger.error(f"Internal Server Error: {str(e)}", exc_info=True)
        return build_response(500, {"error": "Internal Server Error processing chat request"})

def build_response(status_code, body):
    """
    Helper to construct API Gateway compatible response
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*" # Restrict in production via variables
        },
        "body": json.dumps(body)
    }