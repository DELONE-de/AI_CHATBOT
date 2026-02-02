variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Orchestrator Lambda function"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Orchestrator Lambda function"
  type        = string
}

variable "log_retention_days" {
  description = "Retention period for API Gateway Access Logs"
  type        = number
  default     = 30
}

variable "enable_xray" {
  description = "Enable X-Ray tracing for the API Stage"
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Token bucket rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "burst_limit" {
  description = "Token bucket burst limit"
  type        = number
  default     = 200
}