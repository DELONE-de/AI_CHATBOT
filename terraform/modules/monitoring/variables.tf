variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "log_retention_days" {
  description = "Retention period for CloudWatch Logs"
  type        = number
  default     = 90
}

variable "api_gateway_name" {
  description = "Name of the API Gateway (for Alarms)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Orchestrator Lambda (for Alarms)"
  type        = string
}

variable "enable_waf" {
  description = "Enable WAF creation"
  type        = bool
  default     = true
}