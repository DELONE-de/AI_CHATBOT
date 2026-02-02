resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "Entry point for Hotel AI Chatbot"

  endpoint_configuration {
    types = ["REGIONAL"] # Recommended for reduced latency and WAF association
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# /chat Resource & Method
# -----------------------------------------------------------------------------

resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "chat"
}

resource "aws_api_gateway_method" "post_chat" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "POST"
  authorization = "NONE" # Authentication handled via API Keys (below) or delegated

  # Setup API Key requirement for Rate Limiting/Usage Plans
  api_key_required = true

  request_validator_id = aws_api_gateway_request_validator.this.id
}

# -----------------------------------------------------------------------------
# Lambda Integration (Orchestrator)
# -----------------------------------------------------------------------------

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.post_chat.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY" # Pass full request to Lambda
  uri                     = var.lambda_invoke_arn
}

# -----------------------------------------------------------------------------
# Request Validation
# -----------------------------------------------------------------------------

resource "aws_api_gateway_request_validator" "this" {
  name                        = "validate-body-and-params"
  rest_api_id                 = aws_api_gateway_rest_api.this.id
  validate_request_body       = true
  validate_request_parameters = true
}

# -----------------------------------------------------------------------------
# Deployment & Stage
# -----------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Force redeployment on configuration changes
  triggers = {
    redistribution = sha1(jsonencode([
      aws_api_gateway_resource.chat.id,
      aws_api_gateway_method.post_chat.id,
      aws_api_gateway_integration.lambda.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/api-gateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.environment

  xray_tracing_enabled = var.enable_xray

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    # Enterprise JSON format for easy parsing
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true # Logs full request/response data (disable in Prod if PII is sensitive)
    throttling_burst_limit = var.burst_limit
    throttling_rate_limit  = var.rate_limit
  }
}

# -----------------------------------------------------------------------------
# Usage Plan & API Keys (Rate Limiting)
# -----------------------------------------------------------------------------

resource "aws_api_gateway_usage_plan" "this" {
  name        = "${var.project_name}-${var.environment}-plan"
  description = "Usage plan for throttling and quotas"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  quota_settings {
    limit  = 10000
    offset = 0
    period = "DAY"
  }

  throttle_settings {
    burst_limit = var.burst_limit
    rate_limit  = var.rate_limit
  }
}

# Default API Key for generic client
resource "aws_api_gateway_api_key" "client_key" {
  name = "${var.project_name}-${var.environment}-client-key"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.client_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this.id
}

# -----------------------------------------------------------------------------
# Lambda Permission
# -----------------------------------------------------------------------------

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Restrict permission to this specific API Gateway source for security
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# -----------------------------------------------------------------------------
# CORS (Options Method)
# -----------------------------------------------------------------------------

resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'" # Restrict this in production
  }
}