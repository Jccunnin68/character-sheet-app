variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "character-sheet"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "RDS instance class (Free Tier: db.t3.micro)"
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

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8080
}

variable "app_count" {
  description = "Number of app instances to run (Free Tier: keep low)"
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

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (costs money) - use false for Free Tier"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to EKS nodes (optional, for debugging)"
  type        = string
  default     = null
}

variable "api_key" {
  description = "API key for external integrations (optional)"
  type        = string
  default     = null
  sensitive   = true
} 