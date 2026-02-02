resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  bucket_name = "${var.project_name}-${var.environment}-knowledge-${random_string.suffix.result}"
}

# -----------------------------------------------------------------------------
# 1. S3 Bucket (The Knowledge Source)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "knowledge_store" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Purpose     = "Bedrock RAG Source"
  }
}

# -----------------------------------------------------------------------------
# 2. Security Controls
# -----------------------------------------------------------------------------

# Block ALL public access (Enterprise Mandatory)
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.knowledge_store.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-Side Encryption (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.knowledge_store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# -----------------------------------------------------------------------------
# 3. Data Integrity & Lifecycle
# -----------------------------------------------------------------------------

# Enable Versioning (Source of Truth protection)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.knowledge_store.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cost Optimization: Clean up non-current versions after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "cost_optimization" {
  bucket = aws_s3_bucket.knowledge_store.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# -----------------------------------------------------------------------------
# 4. Bucket Policy (Least Privilege)
# -----------------------------------------------------------------------------

# Allow ONLY Bedrock to Read. 
# Explicitly denies unencrypted transport (TLS enforcement).
resource "aws_s3_bucket_policy" "allow_bedrock" {
  bucket = aws_s3_bucket.knowledge_store.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBedrockRead"
        Effect    = "Allow"
        Principal = {
          AWS = var.bedrock_execution_role_arn
        }
        Action    = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource  = [
          aws_s3_bucket.knowledge_store.arn,
          "${aws_s3_bucket.knowledge_store.arn}/*"
        ]
      },
      {
        Sid       = "EnforceTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.knowledge_store.arn,
          "${aws_s3_bucket.knowledge_store.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

