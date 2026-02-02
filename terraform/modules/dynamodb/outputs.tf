output "table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.chat_history.name
}

output "table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = aws_dynamodb_table.chat_history.arn
}

output "table_stream_arn" {
  description = "The ARN of the Table Stream (if enabled for analytics pipelines)"
  value       = aws_dynamodb_table.chat_history.stream_arn
}