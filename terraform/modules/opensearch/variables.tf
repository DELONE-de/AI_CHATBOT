variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "bedrock_execution_role_arn" {
  description = "The ARN of the IAM Role used by Bedrock Knowledge Base. Required for the Access Policy."
  type        = string
}

variable "current_caller_arn" {
  description = "ARN of the current Terraform deployer (to allow index creation/management)"
  type        = string
}