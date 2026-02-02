data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# 1. CloudTrail (Auditing & Governance)
# -----------------------------------------------------------------------------

# KMS Key for encrypting Audit Logs
resource "aws_kms_key" "audit_key" {
  description             = "KMS key for CloudTrail logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "kms:GenerateDataKey*"
        Resource = "*"
        Condition = {
          StringLike = { "kms:EncryptionContext:aws:cloudtrail:arn" : "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*" }
        }
      }
    ]
  })
}

# S3 Bucket for Audit Logs
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "${var.project_name}-${var.environment}-audit-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false # Protect audit logs
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Policy to allow CloudTrail to write
resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.audit_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.audit_logs.arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# The Trail
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${var.environment}-audit-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  s3_key_prefix                 = "prefix"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.audit_key.arn

  depends_on = [aws_s3_bucket_policy.audit_logs]
}

# -----------------------------------------------------------------------------
# 2. CloudWatch Alarms (Observability)
# -----------------------------------------------------------------------------

# Alarm: High 5XX Errors on API Gateway
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-API-High-5XX"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5" # Alert if > 5 errors in 1 minute
  alarm_description   = "API Gateway is returning 5XX errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
  }
}

# Alarm: High Latency on API Gateway
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-API-High-Latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "60"
  statistic           = "Average"
  threshold           = "3000" # 3 Seconds (Allows for Bedrock processing time)
  alarm_description   = "API Gateway latency is high (>3s)"
  
  dimensions = {
    ApiName = var.api_gateway_name
  }
}

# Alarm: Lambda Errors (Orchestrator)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-Lambda-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0" # Alert on ANY error
  alarm_description   = "Orchestrator Lambda is failing"

  dimensions = {
    FunctionName = var.lambda_function_name
  }
}