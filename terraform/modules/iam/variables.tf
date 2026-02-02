variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for chat history"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for IAM permissions"
  type        = string
}

variable "lex_bot_id" {
  description = "The ID of the Amazon Lex V2 Bot"
  type        = string
}

variable "lex_bot_alias_id" {
  description = "The Alias ID of the Amazon Lex V2 Bot"
  type        = string
}

variable "lex_bot_arn" {
  description = "The ARN of the Lex Bot (for IAM permissions)"
  type        = string
}