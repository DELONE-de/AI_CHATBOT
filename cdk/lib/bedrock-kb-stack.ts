import * as cdk from 'aws-cdk-lib';
import * as bedrock from 'aws-cdk-lib/aws-bedrock';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export interface BedrockKBStackProps extends cdk.StackProps {
  // Values provisioned by Terraform
  dataSourceBucketName: string;
  opensearchCollectionArn: string;
  opensearchIndexName: string;
  // Standard Titan or Cohere embedding model ARN
  embeddingModelArn: string; 
}

export class BedrockKBStack extends cdk.Stack {
  public readonly knowledgeBaseId: string;
  public readonly knowledgeBaseArn: string;

  constructor(scope: Construct, id: string, props: BedrockKBStackProps) {
    super(scope, id, props);

    // 1. Import Terraform-managed Resources
    const dataSourceBucket = s3.Bucket.fromBucketName(
      this, 
      'ImportedDocsBucket', 
      props.dataSourceBucketName
    );

    // 2. IAM Role for Bedrock Knowledge Base
    // Allows Bedrock to read from S3 and access OpenSearch
    const kbRole = new iam.Role(this, 'BedrockKBRole', {
      assumedBy: new iam.ServicePrincipal('bedrock.amazonaws.com'),
      description: 'Role used by Bedrock KB to access S3 and OpenSearch',
    });

    dataSourceBucket.grantRead(kbRole);

    // Grant Invoke on the Embedding Model
    kbRole.addToPolicy(new iam.PolicyStatement({
      actions: ['bedrock:InvokeModel'],
      resources: [props.embeddingModelArn],
    }));

    // Grant OpenSearch Access (Note: AOSS data access policies are usually handled in TF)
    // We add the IAM permission here, but the AOSS Collection Policy must allow this Role ARN.
    kbRole.addToPolicy(new iam.PolicyStatement({
      actions: ['aoss:APIAccessAll'],
      resources: [props.opensearchCollectionArn],
    }));

    // 3. Create the Knowledge Base
    const knowledgeBase = new bedrock.CfnKnowledgeBase(this, 'HotelKnowledgeBase', {
      name: 'hotel-ai-knowledge-base',
      roleArn: kbRole.roleArn,
      knowledgeBaseConfiguration: {
        type: 'VECTOR',
        vectorKnowledgeBaseConfiguration: {
          embeddingModelArn: props.embeddingModelArn,
        },
      },
      storageConfiguration: {
        type: 'OPENSEARCH_SERVERLESS',
        opensearchServerlessConfiguration: {
          collectionArn: props.opensearchCollectionArn,
          vectorIndexName: props.opensearchIndexName,
          fieldMapping: {
            vectorField: 'embedding',
            textField: 'text',
            metadataField: 'metadata',
          },
        },
      },
    });

    // 4. Create Data Source (Links S3 to KB)
    new bedrock.CfnDataSource(this, 'HotelKBDataSource', {
      knowledgeBaseId: knowledgeBase.attrKnowledgeBaseId,
      name: 'hotel-docs-datasource',
      dataSourceConfiguration: {
        type: 'S3',
        s3Configuration: {
          bucketArn: dataSourceBucket.bucketArn,
          // Optional: Add inclusion/exclusion prefixes here
        },
      },
    });

    // 5. Exports for Lex Stack
    this.knowledgeBaseId = knowledgeBase.attrKnowledgeBaseId;
    this.knowledgeBaseArn = knowledgeBase.attrKnowledgeBaseArn;

    new cdk.CfnOutput(this, 'BedrockKBId', {
      value: this.knowledgeBaseId,
      description: 'The ID of the Bedrock Knowledge Base',
    });
  }
}