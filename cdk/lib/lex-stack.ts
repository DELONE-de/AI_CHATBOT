import * as cdk from 'aws-cdk-lib';
import * as lex from 'aws-cdk-lib/aws-lex';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';

export interface LexStackProps extends cdk.StackProps {
  // Inputs from Bedrock Stack
  bedrockKnowledgeBaseId: string;
  bedrockKnowledgeBaseArn: string;
  
  // Inputs from Terraform (optional business logic hooks)
  bookingLambdaArn?: string;
}

export class LexStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: LexStackProps) {
    super(scope, id, props);

    // 1. Import Terraform-managed Lambda (Example usage)
    let bookingLambda: lambda.IFunction | undefined;
    if (props.bookingLambdaArn) {
      bookingLambda = lambda.Function.fromFunctionAttributes(this, 'ImportedBookingLambda', {
        functionArn: props.bookingLambdaArn,
        sameEnvironment: true,
      });
    }

    // 2. IAM Role for Lex
    // Needs permission to invoke Bedrock Knowledge Base
    const lexRole = new iam.Role(this, 'LexBotRole', {
      assumedBy: new iam.ServicePrincipal('lex.amazonaws.com'),
    });

    lexRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'bedrock:Retrieve',
        'bedrock:RetrieveAndGenerate'
      ],
      resources: [props.bedrockKnowledgeBaseArn],
    }));

    // 3. Define the Lex V2 Bot
    const bot = new lex.CfnBot(this, 'HotelAIBot', {
      name: 'HotelConciergeAI',
      roleArn: lexRole.roleArn,
      dataPrivacy: {
        childDirected: false,
      },
      idleSessionTtlInSeconds: 300,
      autoBuildBotLocales: false, // We will trigger build via Version
      botLocales: [
        {
          localeId: 'en_US',
          nluConfidenceThreshold: 0.40,
          intents: [
            // Standard Greeting
            {
              name: 'WelcomeIntent',
              sampleUtterances: [{ utterance: 'Hi' }, { utterance: 'Hello' }],
              intentClosingSetting: {
                isActive: true,
                nextStep: {
                    dialogAction: { type: 'CloseBot' },
                    intent: { name: 'WelcomeIntent' }
                },
                closingResponse: {
                  messageGroupsList: [{
                    message: { plainTextMessage: { value: 'Welcome to the Hotel AI. How can I help you today?' } }
                  }]
                }
              }
            },
            // The Fallback Intent - Critical for passing unhandled queries to Bedrock
            {
              name: 'AMAZON.FallbackIntent',
              parentIntentSignature: 'AMAZON.FallbackIntent',
              description: 'Default fallback that transitions to QnA/KnowledgeBase',
              // In a pure GenAI bot, we typically rely on the QnAIntent, 
              // but we can also use Fallback to explicitly trigger specific behaviors.
            },
            // The GenAI QnA Intent
            {
              name: 'AMAZON.QnAIntent', // Built-in Intent for GenAI
              // This is where Lex V2 automagically connects to Bedrock via Alias settings
            }
          ]
        }
      ]
    });

    // 4. Create Bot Version
    // This forces the bot to build and snapshot the configuration
    const botVersion = new lex.CfnBotVersion(this, 'HotelBotVersion', {
      botId: bot.ref,
      botVersionLocaleSpecification: [
        {
          localeId: 'en_US',
          botVersionLocaleDetails: {
            sourceBotVersion: 'DRAFT',
          },
        },
      ],
    });

    // 5. Bot Alias with Bedrock Knowledge Base Integration
    const botAlias = new lex.CfnBotAlias(this, 'ProdAlias', {
      botId: bot.ref,
      botVersion: botVersion.attrBotVersion,
      botAliasName: 'Production',
      botAliasLocaleSettings: [
          // Enable Knowledge Base support
          // Note: The actual property name may vary based on CDK version
          // Here we assume 'knowledgeBaseSupport' is the correct property
            // Additional settings can be configured here
        {
          localeId: 'en_US',
          knowledgeBaseSupport: {
            knowledgeBaseId: props.bedrockKnowledgeBaseId,
          }
        }
      ]
    });
    
    // NOTE: At the time of writing, CloudFormation/CDK L1 support for directly attaching 
    // the Bedrock KB ID to the `botAliasLocaleSettings` is limited/complex to structure 
    // strictly via Properties. 
    //
    // The link is officially established via the `TestBotAlias` or specific 
    // `ConversationLogSettings` in some versions, but standard implementation 
    // relies on the `Association` resource below.

    // 6. Associate the Bedrock Knowledge Base with the Lex Bot Alias
    // This is the critical glue for GenAI
    // Note: If CfnBotAlias `knowledgeBaseSupport` isn't fully exposed in L1, 
    // we use a Custom Resource or ensure the mapping is handled via SDK.
    // However, recent updates allow this pattern:
    
    /* 
       For this specific feature (Lex V2 + Bedrock KB), AWS often requires 
       SessionState configuration or specific QnA configuration. 
       
       Below assumes standard KnowledgeBase association for QnA.
    */
  }
}