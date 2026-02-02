#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { BedrockKBStack } from '../lib/bedrock-kb-stack';
import { LexStack } from '../lib/lex-stack';

const app = new cdk.App();

// In an enterprise setup, these are often loaded via SSM Parameter Store lookups
// or passed as Context (-c) during the deployment pipeline.
const terraformOutputs = {
    dataSourceBucketName: process.env.TF_OUT_S3_BUCKET || 'hotel-ai-docs-bucket-prod',
    opensearchCollectionArn: process.env.TF_OUT_OSS_ARN || 'arn:aws:aoss:us-east-1:123456789012:collection/id',
    opensearchIndexName: 'hotel-docs-index',
    bookingLambdaArn: process.env.TF_OUT_LAMBDA_ARN || 'arn:aws:lambda:us-east-1:123456789012:function:booking-func',
    embeddingModelArn: 'arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1',
};

const bedrockStack = new BedrockKBStack(app, 'HotelBedrockKBStack', {
    dataSourceBucketName: terraformOutputs.dataSourceBucketName,
    opensearchCollectionArn: terraformOutputs.opensearchCollectionArn,
    opensearchIndexName: terraformOutputs.opensearchIndexName,
    embeddingModelArn: terraformOutputs.embeddingModelArn,
    env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: 'us-east-1' },
});

const lexStack = new LexStack(app, 'HotelLexStack', {
    bedrockKnowledgeBaseId: bedrockStack.knowledgeBaseId,
    bedrockKnowledgeBaseArn: bedrockStack.knowledgeBaseArn,
    bookingLambdaArn: terraformOutputs.bookingLambdaArn,
    env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: 'us-east-1' },
});

// Lex depends on Bedrock KB existing first
lexStack.addDependency(bedrockStack);