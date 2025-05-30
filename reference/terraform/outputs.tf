# Outputs for ECS Reference Implementation
# ========================================
# This file contains outputs for important resource information.

# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = var.enable_nat_gateway ? aws_subnet.private[*].id : []
}

output "public_private_subnet_ids" {
  description = "IDs of the public-private subnets (Free Tier)"
  value       = var.enable_nat_gateway ? [] : aws_subnet.public_private[*].id
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

# Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.app.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.app.arn
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_url" {
  description = "Database connection URL"
  value       = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}/${var.db_name}?sslmode=disable"
  sensitive   = true
}

# S3 and CloudFront Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown"
  value = {
    ec2_instances      = "Free Tier (750 hours)"
    rds_instance      = "Free Tier (750 hours)"
    rds_storage       = "Free Tier (20GB)"
    s3_storage        = "Free Tier (5GB)"
    cloudfront        = "Free Tier (1TB transfer)"
    cloudwatch_logs   = "Free Tier (5GB)"
    nat_gateway       = var.enable_nat_gateway ? "$32/month" : "$0 (disabled)"
    estimated_total   = var.enable_nat_gateway ? "$32-40/month" : "$0-8/month"
  }
}

# Connection Information
output "application_urls" {
  description = "URLs to access the application"
  value = {
    backend_alb       = "http://${aws_lb.app.dns_name}"
    frontend_s3       = "http://${aws_s3_bucket.frontend.bucket_domain_name}"
    frontend_cloudfront = "https://${aws_cloudfront_distribution.frontend.domain_name}"
  }
}

# Security Group IDs
output "security_groups" {
  description = "Security group IDs"
  value = {
    alb            = aws_security_group.alb.id
    ecs_instances  = aws_security_group.ecs_instances.id
    rds           = aws_security_group.rds.id
    vpc_endpoints = aws_security_group.vpc_endpoints.id
  }
}

# IAM Role ARNs
output "iam_roles" {
  description = "IAM role ARNs"
  value = {
    ecs_instance_role      = aws_iam_role.ecs_instance_role.arn
    ecs_task_execution     = aws_iam_role.ecs_task_execution_role.arn
    ecs_task_role         = aws_iam_role.ecs_task_role.arn
  }
}

# ECR Repository URL
output "ecr_repository_url" {
  description = "ECR repository URL for backend images"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-backend"
}

# Region Information
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
} 