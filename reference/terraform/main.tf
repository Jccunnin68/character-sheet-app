# Main Terraform Configuration for ECS Reference Implementation
# =============================================================
# This file contains the provider configuration and data sources
# for the ECS reference implementation.

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Data Sources
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Random string for unique resource naming
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
} 