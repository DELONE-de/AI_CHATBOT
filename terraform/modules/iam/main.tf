# -----------------------------------------------------------------------------
# IAM Role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-orchestrator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 2. X-Ray Tracing
resource "aws_iam_role_policy_attachment" "xray_write" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}













# -----------------------------------------------------------------------------
# Policies
# -----------------------------------------------------------------------------
# 3. Custom Policy: Lex & DynamoDB Access (Least Privilege)
resource "aws_iam_policy" "orchestrator_policy" {
  name        = "${var.project_name}-${var.environment}-orchestrator-policy"
  description = "Allow Lambda to call Lex and write to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLex"
        Effect = "Allow"
        Action = [
          "lex:RecognizeText",
          "lex:StartConversation"
        ]
        # Scope strictly to the specific Bot to prevent cross-bot invocation
        Resource = "${var.lex_bot_arn}/*" 
      },
      {
        Sid    = "WriteChatHistory"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = var.dynamodb_table_arn
      }
    ]
  })
}