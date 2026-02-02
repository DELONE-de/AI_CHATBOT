resource "aws_dynamodb_table" "chat_history" {
  name         = "${var.project_name}-${var.environment}-chat-history"
  billing_mode = "PAY_PER_REQUEST" # Serverless mode
  hash_key     = "sessionId"
  range_key    = "timestamp"

  # -----------------------------------------------------------------------------
  # Primary Key Definitions
  # -----------------------------------------------------------------------------
  attribute {
    name = "sessionId"
    type = "S" # String (UUID from Lambda/Lex)
  }

  attribute {
    name = "timestamp"
    type = "N" # Number (Unix Epoch)
  }

  attribute {
    name = "chatId"
    type = "S" # String (Client-side unique ID)
  }

  # -----------------------------------------------------------------------------
  # Time To Live (Cost Optimization)
  # -----------------------------------------------------------------------------
  # Automatically deletes items after the TTL timestamp is passed.
  # This prevents indefinite storage growth of transient chat logs.
  ttl {
    attribute_name = var.ttl_attribute_name
    enabled        = true
  }

  # -----------------------------------------------------------------------------
  # Global Secondary Index (GSI)
  # -----------------------------------------------------------------------------
  # Allows querying history by 'chatId' (User ID) across multiple Lex sessions.
  global_secondary_index {
    name               = "ChatHistoryIndex"
    hash_key           = "chatId"
    range_key          = "timestamp"
    projection_type    = "ALL" # Project all attributes for full context retrieval
  }

  # -----------------------------------------------------------------------------
  # Security & Compliance
  # -----------------------------------------------------------------------------
  
  # Encryption at Rest (Standard Enterprise Requirement)
  server_side_encryption {
    enabled = true 
    # uses AWS Owned Key by default, can be switched to Customer Managed (KMS) if strictly required
  }

  # Auditing & Recovery
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-chat-history"
    Environment = var.environment
    Purpose     = "Audit and Session Store"
  }
}