output "waf_web_acl_arn" {
  description = "The ARN of the WAF Web ACL to be associated with API Gateway"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : ""
}

output "audit_bucket_name" {
  description = "Name of the S3 bucket storing audit logs"
  value       = aws_s3_bucket.audit_logs.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for CloudTrail encryption"
  value       = aws_kms_key.audit_key.arn
}