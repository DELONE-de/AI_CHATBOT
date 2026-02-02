resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  # OpenSearch Serverless names must be lowercase and simple
  collection_name = "${var.project_name}-${var.environment}-vec-${random_string.suffix.result}"
}

# -----------------------------------------------------------------------------
# 1. Serverless Collection (The Vector Store)
# -----------------------------------------------------------------------------
resource "aws_opensearchserverless_collection" "this" {
  name             = local.collection_name
  type             = "VECTORSEARCH"
  description      = "Vector store for Hotel AI Chatbot RAG"
  
  # Ensure encryption policy exists before creating collection
  depends_on = [aws_opensearchserverless_security_policy.encryption]

  tags = {
    Name        = local.collection_name
    Environment = var.environment
    Project     = var.project_name
  }
}

# -----------------------------------------------------------------------------
# 2. Encryption Policy (Security)
# -----------------------------------------------------------------------------
# Enforces encryption at rest using AWS owned keys (or customer managed if needed)
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${local.collection_name}-enc"
  type        = "encryption"
  description = "Encryption policy for Hotel RAG collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource = [
          "collection/${local.collection_name}"
        ]
      }
    ],
    AWSOwnedKey = true
  })
}

# -----------------------------------------------------------------------------
# 3. Network Policy (Connectivity)
# -----------------------------------------------------------------------------
# Allows access to the endpoint. Security is handled by the IAM Access Policy.
# Note: For strict VPC isolation, this would be type 'vpc', but Bedrock integration
# is standard via the public endpoint protected by SigV4 IAM auth.
resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${local.collection_name}-net"
  type        = "network"
  description = "Network policy for Hotel RAG collection"

  policy = jsonencode([
    {
      Description = "Public access for Bedrock via IAM"
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${local.collection_name}"
          ]
        },
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/${local.collection_name}"
          ]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# -----------------------------------------------------------------------------
# 4. Access Policy (IAM Authorization)
# -----------------------------------------------------------------------------
# STRICT ACCESS CONTROL:
# Only the Bedrock Role and the Deployer can access data.
resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "${local.collection_name}-access"
  type        = "data"
  description = "Data access policy for Bedrock and Admin"

  policy = jsonencode([
    {
      Description = "Allow Bedrock Knowledge Base Access"
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${local.collection_name}"
          ]
          Permission = [
            "aoss:DescribeCollectionItems",
            "aoss:CreateCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DeleteCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource = [
            "index/${local.collection_name}/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = [
        var.bedrock_execution_role_arn
      ]
    },
    {
      Description = "Allow Terraform Deployer/Admin Access"
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/${local.collection_name}"
          ]
          Permission = [
            "aoss:*"
          ]
        },
        {
          ResourceType = "index"
          Resource = [
            "index/${local.collection_name}/*"
          ]
          Permission = [
            "aoss:*"
          ]
        }
      ]
      Principal = [
        var.current_caller_arn
      ]
    }
  ])
}