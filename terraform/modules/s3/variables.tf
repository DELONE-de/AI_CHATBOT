variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "bedrock_execution_role_arn" {
  description = "The ARN of the IAM Role used by Bedrock Knowledge Base. This role is granted Read access."
  type        = string
}

variable "force_destroy" {
  description = "Allow destruction of the bucket even if it contains objects (useful for dev/staging)"
  type        = bool
  default     = false
}