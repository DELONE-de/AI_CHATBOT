data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Zip Source Code
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/orchestrator.py"
  output_path = "${path.module}/orchestrator.zip"
}



resource "aws_iam_role_policy_attachment" "custom_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.orchestrator_policy.arn
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "orchestrator" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-orchestrator"
  role             = aws_iam_role.lambda_role.arn
  handler          = "orchestrator.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  
  # Timeout: Needs to be higher than Lex + Bedrock latency. 
  # API Gateway max is 29s. We set 20s to fail gracefully before APIGW kills it.
  timeout          = 20
  memory_size      = 256

  environment {
    variables = {
      LEX_BOT_ID          = var.lex_bot_id
      LEX_BOT_ALIAS_ID    = var.lex_bot_alias_id
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      LOG_LEVEL           = "INFO"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "${var.project_name}-orchestrator"
    Environment = var.environment
  }
}