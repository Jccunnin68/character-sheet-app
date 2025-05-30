# Variables for ECS Reference Implementation
# ==========================================
# This file contains all variables needed for the ECS reference implementation.
# These are optimized for AWS Free Tier usage and single-environment deployment.

# Basic Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "character-sheet"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway (costs ~$32/month - disable for Free Tier)"
  type        = bool
  default     = false
}

# Application Configuration
variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path for load balancer"
  type        = string
  default     = "/health"
}

variable "app_count" {
  description = "Number of app instances (keep at 1 for Free Tier)"
  type        = number
  default     = 1
}

# Database Configuration
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "charactersheet"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class (db.t3.micro for Free Tier)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Database storage in GB (20GB max for Free Tier)"
  type        = number
  default     = 20
}

# Security Configuration
variable "jwt_secret" {
  description = "JWT signing secret (minimum 32 characters)"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access (optional)"
  type        = string
  default     = ""
}

# Cost Optimization
variable "instance_type" {
  description = "EC2 instance type for ECS hosts (t3.micro for Free Tier)"
  type        = string
  default     = "t3.micro"
}

variable "min_capacity" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 1
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days (keep minimal for Free Tier)"
  type        = number
  default     = 3
}

# Frontend Configuration (S3 + CloudFront)
variable "enable_cloudfront" {
  description = "Whether to enable CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Project     = "character-sheet"
    Owner       = "DevOps"
  }
} 