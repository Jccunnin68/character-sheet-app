variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, preprod, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "preprod", "prod"], var.environment)
    error_message = "Environment must be one of: dev, preprod, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "character-sheet"
}

# Multi-account configuration
variable "target_account_id" {
  description = "AWS Account ID where this environment will be deployed"
  type        = string
}

variable "shared_account_id" {
  description = "AWS Account ID containing shared resources (ECR, networking)"
  type        = string
}

# ECR Configuration
variable "ecr_repository_url" {
  description = "ECR repository URL from shared account"
  type        = string
}

# Networking configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# EKS Node configuration
variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

variable "node_instance_types" {
  description = "Instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

# Database configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "character_sheets"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "backup_retention_period" {
  description = "Database backup retention period in days"
  type        = number
  default     = 0
}

variable "multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

# Application configuration
variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8080
}

variable "app_count" {
  description = "Number of app instances to run"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "Health check path for the application"
  type        = string
  default     = "/health"
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  sensitive   = true
}

# Cost optimization
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (costs money) - use false for cost optimization"
  type        = bool
  default     = false
}

# Optional configurations
variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to EKS nodes (optional)"
  type        = string
  default     = null
}

variable "api_key" {
  description = "API key for external integrations (optional)"
  type        = string
  default     = null
  sensitive   = true
} 