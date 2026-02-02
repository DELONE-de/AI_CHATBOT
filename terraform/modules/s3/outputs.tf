output "bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.knowledge_store.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.knowledge_store.arn
}

output "bucket_domain_name" {
  description = "The domain name of the bucket"
  value       = aws_s3_bucket.knowledge_store.bucket_domain_name
}