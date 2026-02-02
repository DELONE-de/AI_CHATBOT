
data "aws_caller_identity" "current" {}
data "aws_cloudformation_export" "lex_bot_alias_arn" {
  name = "LexBotAliasArn"
}

data "aws_cloudformation_export" "lex_bot_id" {
  name = "LexBotId" 
}

data "aws_cloudformation_export" "lex_bot_arn" {
  name = "LexBotArn"
}


module "glo" {
  source = "../../global"
  aws_region = var.aws_region
}

module "dynamodb" {
  source = "../../modules/dynamodb"
  environment = var.environment
  project_name = var.project_name
}

module "iam" {
  source = "../../modules/iam"
  project_name = var.project_name
  environment = var.environment
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn = module.dynamodb.table_arn
  lex_bot_id = "placeholder"
  lex_bot_alias_id = "placeholder"
  lex_bot_arn = "arn:aws:lex:${var.aws_region}:${data.aws_caller_identity.current.account_id}:bot-alias/placeholder/placeholder"
}

module "s3" {
  source = "../../modules/s3"
  project_name = var.project_name
  environment = var.environment
  bedrock_execution_role_arn = module.iam.bedrock_role_arn
}

module "opensearch" {
  source = "../../modules/opensearch"
  project_name = var.project_name
  environment = var.environment
  bedrock_execution_role_arn = module.iam.bedrock_role_arn
  current_caller_arn = data.aws_caller_identity.current.arn
}

module "lambda" {
  source = "../../modules/lambda"
  environment = var.environment
  dynamodb_table_arn = module.dynamodb.table_arn
  lex_bot_id = data.aws_cloudformation_export.lex_bot_id
  project_name = var.project_name
  dynamodb_table_name = module.dynamodb.table_name
  lex_bot_alias_id = data.aws_cloudformation_export.lex_bot_alias_arn
  lex_bot_arn = data.aws_cloudformation_export.lex_bot_arn
}

module "api_gateway" {
  source = "../../modules/api-gateway"
  environment = var.environment
  lambda_function_name = module.lambda.function_name
  region = var.aws_region
  lambda_invoke_arn = module.lambda.lambda_invoke_arn
  project_name = var.project_name
}

module "monitoring" {
  source = "../../modules/monitoring"
  project_name = var.project_name
  environment = var.environment
  api_gateway_name = module.api_gateway.api_name
  lambda_function_name = module.lambda.function_name
  region = var.aws_region
}

