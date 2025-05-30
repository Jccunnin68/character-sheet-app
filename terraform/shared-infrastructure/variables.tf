variable "aws_region" {
  description = "AWS region for shared infrastructure"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "character-sheet"
}

variable "dev_account_id" {
  description = "AWS Account ID for Dev environment"
  type        = string
}

variable "preprod_account_id" {
  description = "AWS Account ID for PreProd environment"
  type        = string
}

variable "prod_account_id" {
  description = "AWS Account ID for Production environment"
  type        = string
}

variable "create_terraform_state_bucket" {
  description = "Whether to create S3 bucket for Terraform state"
  type        = bool
  default     = false
} 