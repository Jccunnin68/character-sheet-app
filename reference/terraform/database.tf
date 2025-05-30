# Database Infrastructure for ECS Reference Implementation
# ========================================================
# This file contains the RDS PostgreSQL database configuration
# optimized for AWS Free Tier usage.

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public_private[*].id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
  })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  # For Free Tier with public subnets, allow from VPC CIDR
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
  })
}

# RDS Parameter Group (optional customization)
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-${var.environment}-pg"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-pg"
    Environment = var.environment
  })
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}"

  # Engine Configuration
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  # Storage Configuration
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp2"
  storage_encrypted     = false # Not included in Free Tier

  # Database Configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = !var.enable_nat_gateway # True for Free Tier setup

  # Backup Configuration
  backup_retention_period = 0  # No backups for Free Tier
  backup_window          = "09:46-10:16"
  maintenance_window     = "Mon:00:00-Mon:03:00"

  # Performance Configuration
  parameter_group_name = aws_db_parameter_group.main.name
  monitoring_interval  = 0 # Disable enhanced monitoring for Free Tier

  # Deletion Configuration
  skip_final_snapshot       = true
  delete_automated_backups  = true
  deletion_protection       = false

  # Cost Optimization
  auto_minor_version_upgrade = true
  apply_immediately         = true

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-rds"
    Environment = var.environment
  })
}

# Random password for demo purposes (in production, use AWS Secrets Manager)
resource "random_password" "db_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 16
  special = true
}

# Store the password in AWS Secrets Manager (optional)
resource "aws_secretsmanager_secret" "db_password" {
  count                   = var.db_password == "" ? 1 : 0
  name                    = "${var.project_name}-${var.environment}-db-password"
  recovery_window_in_days = 0 # Immediate deletion for dev environments

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count     = var.db_password == "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_password[0].id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password[0].result
  })
} 