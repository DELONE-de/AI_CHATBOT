output "api_endpoint" {
  description = "The Invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "api_arn" {
  description = "The ARN of the API Gateway (Used for WAF association)"
  value       = aws_api_gateway_stage.this.arn
}

output "api_execution_arn" {
  description = "The execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "api_key_value" {
  description = "The API Key value (Sensitive - handle with care in logs)"
  value       = aws_api_gateway_api_key.client_key.value
  sensitive   = true
}