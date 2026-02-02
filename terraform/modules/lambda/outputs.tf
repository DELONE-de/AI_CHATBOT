output "function_name" {
  description = "Name of the Orchestrator Lambda"
  value       = aws_lambda_function.orchestrator.function_name
}

output "function_arn" {
  description = "ARN of the Orchestrator Lambda"
  value       = aws_lambda_function.orchestrator.arn
}

output "invoke_arn" {
  description = "Invoke ARN for API Gateway integration"
  value       = aws_lambda_function.orchestrator.invoke_arn
}

output "role_name" {
  description = "IAM Role name of the Lambda (useful for adding extra policies if needed)"
  value       = aws_iam_role.lambda_role.name
}