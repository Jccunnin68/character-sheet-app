# ECR Repository outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.character_sheet_backend.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.character_sheet_backend.arn
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.character_sheet_backend.name
}

# CloudWatch outputs
output "shared_log_group_name" {
  description = "Name of the shared CloudWatch log group"
  value       = aws_cloudwatch_log_group.shared_logs.name
}

output "shared_log_group_arn" {
  description = "ARN of the shared CloudWatch log group"
  value       = aws_cloudwatch_log_group.shared_logs.arn
}

# Terraform state bucket outputs
output "terraform_state_bucket_name" {
  description = "Name of the Terraform state bucket (if created)"
  value       = var.create_terraform_state_bucket ? aws_s3_bucket.terraform_state[0].bucket : null
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state bucket (if created)"
  value       = var.create_terraform_state_bucket ? aws_s3_bucket.terraform_state[0].arn : null
}

# Account information
output "shared_account_id" {
  description = "AWS Account ID where shared infrastructure is deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region where shared infrastructure is deployed"
  value       = var.aws_region
} 