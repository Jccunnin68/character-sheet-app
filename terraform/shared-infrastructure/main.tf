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

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_caller_identity" "current" {}

# ECR Repository for all environments
resource "aws_ecr_repository" "character_sheet_backend" {
  name                 = "character-sheet-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "character-sheet-backend"
    Environment = "shared"
    Component   = "container-registry"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "character_sheet_backend" {
  repository = aws_ecr_repository.character_sheet_backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 preprod images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["preprod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 3 dev images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Cross-account ECR permissions for dev account
resource "aws_ecr_repository_policy" "dev_access" {
  repository = aws_ecr_repository.character_sheet_backend.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountAccessDev"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.dev_account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
      },
      {
        Sid    = "CrossAccountAccessPreProd"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.preprod_account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
      },
      {
        Sid    = "CrossAccountAccessProd"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.prod_account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
      }
    ]
  })
}

# CloudWatch Log Group for shared monitoring
resource "aws_cloudwatch_log_group" "shared_logs" {
  name              = "/character-sheet/shared"
  retention_in_days = 30

  tags = {
    Name        = "character-sheet-shared-logs"
    Environment = "shared"
    Component   = "monitoring"
  }
}

# S3 Bucket for Terraform state (if needed)
resource "aws_s3_bucket" "terraform_state" {
  count  = var.create_terraform_state_bucket ? 1 : 0
  bucket = "character-sheet-terraform-state-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "character-sheet-terraform-state"
    Environment = "shared"
    Component   = "infrastructure"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.create_terraform_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.create_terraform_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.create_terraform_state_bucket ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
} 