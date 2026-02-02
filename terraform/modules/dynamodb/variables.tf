variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "ttl_attribute_name" {
  description = "The attribute name to be used for Time-To-Live (TTL)"
  type        = string
  default     = "ttl"
}