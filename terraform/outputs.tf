output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "aws_region" {
  description = "AWS region used for deployment"
  value       = var.aws_region
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public_private[*].id
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "alb_hostname" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer"
  value       = aws_lb.app.zone_id
}

# EKS-specific outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.eks_cluster.name
}

output "eks_cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.main.arn
}

output "eks_node_group_status" {
  description = "Status of the EKS Node Group"
  value       = aws_eks_node_group.main.status
}

# WAF outputs
output "waf_acl_arn" {
  description = "ARN of the WAF Web ACL for geo-restriction"
  value       = aws_wafv2_web_acl.geo_restriction.arn
}

output "waf_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.geo_restriction.id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

# Kubectl configuration command
output "configure_kubectl" {
  description = "Configure kubectl"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${aws_eks_cluster.main.id}"
}

output "cluster_configuration" {
  description = "EKS cluster configuration summary"
  value = {
    cluster_name           = aws_eks_cluster.main.name
    kubernetes_version     = aws_eks_cluster.main.version
    node_instance_types    = ["t3.small"]
    node_desired_capacity  = 2
    node_min_size         = 1
    node_max_size         = 4
    nat_gateway_enabled   = var.enable_nat_gateway
    waf_enabled           = true
    geo_restriction       = "US, Canada, Europe only"
    estimated_monthly_cost = var.enable_nat_gateway ? "$80-120 (with NAT Gateway)" : "$40-60 (without NAT Gateway)"
  }
}

# Secrets Manager outputs
output "database_secret_arn" {
  description = "ARN of the database secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.database.arn
}

output "backend_secret_arn" {
  description = "ARN of the backend secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.backend.arn
}

# External Secrets Operator IAM Role
output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

# AWS Load Balancer Controller IAM Role
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

# OIDC Provider
output "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
} 