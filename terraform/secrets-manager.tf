# AWS Secrets Manager Configuration
# This file creates AWS Secrets Manager secrets and IAM roles for External Secrets Operator
# Replaces hardcoded secrets in Kubernetes manifests with secure AWS-managed secrets

# Database secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "database" {
  name                    = "character-sheet/database"
  description             = "Database credentials for Character Sheet application"
  recovery_window_in_days = 0  # For development - immediate deletion allowed

  tags = {
    Name        = "${var.project_name}-${var.environment}-database-secret"
    Environment = var.environment
    Component   = "database"
  }
}

# Database secret values
resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    database = var.db_name
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
  })
}

# Backend application secrets in AWS Secrets Manager
resource "aws_secretsmanager_secret" "backend" {
  name                    = "character-sheet/backend"
  description             = "Backend API credentials for Character Sheet application"
  recovery_window_in_days = 0  # For development - immediate deletion allowed

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-secret"
    Environment = var.environment
    Component   = "backend"
  }
}

# Backend secret values
resource "aws_secretsmanager_secret_version" "backend" {
  secret_id = aws_secretsmanager_secret.backend.id
  secret_string = jsonencode({
    jwt_secret = var.jwt_secret
    api_key    = var.api_key != null ? var.api_key : ""
  })
}

# Get AWS account ID for IAM role ARNs
data "aws_caller_identity" "current" {}

# Get EKS cluster OIDC issuer
data "aws_eks_cluster" "main" {
  name = aws_eks_cluster.main.name
}

# Data source for EKS cluster OIDC issuer URL
data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# OIDC Identity Provider for EKS
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-oidc"
    Environment = var.environment
  }
}

# IAM Role for External Secrets Operator
resource "aws_iam_role" "external_secrets" {
  name = "${var.project_name}-${var.environment}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:character-sheet:external-secrets-sa"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-external-secrets-role"
    Environment = var.environment
  }
}

# IAM Policy for External Secrets Operator to access Secrets Manager
resource "aws_iam_policy" "external_secrets" {
  name        = "${var.project_name}-${var.environment}-external-secrets-policy"
  description = "Policy for External Secrets Operator to access AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.database.arn,
          aws_secretsmanager_secret.backend.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "secretsmanager:Name" = "character-sheet/*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-external-secrets-policy"
    Environment = var.environment
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

# CloudWatch Log Group for External Secrets Operator
resource "aws_cloudwatch_log_group" "external_secrets" {
  name              = "/aws/eks/${var.project_name}-${var.environment}/external-secrets"
  retention_in_days = 7  # Cost optimization

  tags = {
    Name        = "${var.project_name}-${var.environment}-external-secrets-logs"
    Environment = var.environment
  }
}

# IAM Role for AWS Load Balancer Controller (if not exists)
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-${var.environment}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-aws-load-balancer-controller"
    Environment = var.environment
  }
}

# Attach AWS Load Balancer Controller policy
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# Additional policy for ALB controller
resource "aws_iam_policy" "aws_load_balancer_controller_additional" {
  name        = "${var.project_name}-${var.environment}-alb-controller-additional"
  description = "Additional permissions for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DescribeSubscription",
          "shield:ListProtections"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:*/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateNetworkInterface",
              "CreateSecurityGroup"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_additional" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_additional.arn
} 