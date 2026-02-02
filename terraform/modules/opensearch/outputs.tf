output "collection_arn" {
  description = "The ARN of the OpenSearch Serverless Collection"
  value       = aws_opensearchserverless_collection.this.arn
}

output "collection_id" {
  description = "The ID of the OpenSearch Serverless Collection"
  value       = aws_opensearchserverless_collection.this.id
}

output "collection_endpoint" {
  description = "The HTTP endpoint of the OpenSearch Serverless Collection"
  value       = aws_opensearchserverless_collection.this.collection_endpoint
}

output "collection_name" {
  description = "The name of the collection (used for index naming conventions)"
  value       = aws_opensearchserverless_collection.this.name
}