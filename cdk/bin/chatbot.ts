#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { LexStack } from '../lib/lex-stack';
import { BedrockKBStack } from '../lib/bedrock-kb-stack';

const app = new cdk.App();

// Deploy Lex bot stack
new LexStack(app, 'LexStack', {
  /* add environment / resource info here */
});

// Deploy Bedrock Knowledge Base attachment stack
new BedrockKBStack(app, 'BedrockKBStack', {
  /* add environment / resource info here */
});
