resource "aws_wafv2_web_acl" "main" {
  count       = var.enable_waf ? 1 : 0
  name        = "${var.project_name}-${var.environment}-web-acl"
  description = "WAF for Hotel Chatbot API"
  scope       = "REGIONAL" # For API Gateway (Regional)

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metric"
    sampled_requests_enabled   = true
  }

  # 1. AWS Managed Common Rule Set (OWASP Top 10 equivalent)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-CommonRules"
      sampled_requests_enabled   = true
    }
  }

  # 2. AWS Managed IP Reputation List (Block known bad actors)
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-IpReputation"
      sampled_requests_enabled   = true
    }
  }

  # 3. Rate Limiting (DDoS Protection)
  # Limit IPs to 500 requests per 5 minutes
  rule {
    name     = "RateLimit"
    priority = 30
    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 500
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name        = "${var.project_name}-waf"
    Environment = var.environment
  }
}