# RDS Subnet Group - Use appropriate subnets based on NAT Gateway setting
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public_private[*].id

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  # For Free Tier with public subnets, allow access from VPC CIDR
  dynamic "ingress" {
    for_each = var.enable_nat_gateway ? [] : [1]
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-db-params"

  # Free Tier optimized parameters
  parameter {
    name  = "shared_preload_libraries"
    value = ""
  }

  parameter {
    name  = "log_statement"
    value = "none" # Reduce logging for Free Tier
  }

  tags = {
    Name        = "${var.project_name}-db-params"
    Environment = var.environment
  }
}

# RDS Instance - Free Tier optimized
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}"

  # Engine - Free Tier
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class # db.t3.micro for Free Tier

  # Storage - Free Tier: 20GB included
  allocated_storage     = 20
  max_allocated_storage = 20 # Don't enable auto-scaling for Free Tier
  storage_type          = "gp2"
  storage_encrypted     = false # Encryption not included in Free Tier

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.enable_nat_gateway ? false : true # Public for Free Tier

  # Backup - Free Tier: 0 days (no backup retention)
  backup_retention_period = 0 # Free Tier doesn't include automated backups
  backup_window          = null
  maintenance_window     = "sun:04:00-sun:05:00"

  # Monitoring - Disable for Free Tier
  monitoring_interval = 0 # Enhanced monitoring costs extra
  monitoring_role_arn = null

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.main.name

  # Deletion protection
  deletion_protection      = false
  skip_final_snapshot     = true
  final_snapshot_identifier = null

  # Performance Insights - Not included in Free Tier
  performance_insights_enabled = false

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
} 