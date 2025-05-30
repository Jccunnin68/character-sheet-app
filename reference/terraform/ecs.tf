# ECS Implementation - REFERENCE ONLY
# =====================================
# This file contains the ECS implementation for comparison and reference.
# The current multi-environment setup uses EKS (see eks.tf).
# 
# This ECS implementation was optimized for AWS Free Tier and demonstrates:
# - ECS on EC2 (better Free Tier utilization than Fargate)
# - Auto Scaling Groups with single instance for cost optimization
# - Dynamic port mapping with ALB integration
# - SSH access for debugging
# 
# To use ECS instead of EKS:
# 1. Copy this file content to a new ecs.tf
# 2. Update variables.tf for ECS-specific configurations
# 3. Modify GitHub Actions workflows for ECS deployment
# 4. Update ALB target groups for ECS service discovery
#
# COST COMPARISON (monthly estimates):
# - EKS Setup: $75+ (EKS control plane) + worker nodes
# - ECS Setup: $0 (no control plane cost) + EC2 instances only
# =====================================

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}"

  # Container Insights costs extra - disable for Free Tier
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

# Launch Template for ECS EC2 instances
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = "t3.micro" # Free Tier eligible

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = "${var.project_name}-${var.environment}"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-ecs-instance"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-ecs-launch-template"
    Environment = var.environment
  }
}

# Auto Scaling Group for ECS instances
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg"
  vpc_zone_identifier = var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public_private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  # Ensure instances are replaced with zero downtime
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# Capacity Provider for ECS Cluster
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name        = "${var.project_name}-capacity-provider"
    Environment = var.environment
  }
}

# Associate capacity provider with cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main.name
  }
}

# Data source for ECS-optimized AMI
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# IAM Role for ECS instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name

  tags = {
    Name        = "${var.project_name}-ecs-instance-profile"
    Environment = var.environment
  }
}

# Security Group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name_prefix = "${var.project_name}-ecs-instances-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # For Free Tier with public subnets, allow HTTP from anywhere
  dynamic "ingress" {
    for_each = var.enable_nat_gateway ? [] : [1]
    content {
      from_port   = var.container_port
      to_port     = var.container_port
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # SSH access for debugging (optional)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Dynamic port range for ECS tasks
  ingress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-instances-sg"
    Environment = var.environment
  }
}

# ECS Task Execution Role (still needed for ECR and CloudWatch)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-role"
    Environment = var.environment
  }
}

# CloudWatch Log Group - Free Tier: 5GB included
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 3 # Minimal retention for Free Tier

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Environment = var.environment
  }
}

# ECS Task Definition - EC2 optimized
resource "aws_ecs_task_definition" "app" {
  family                = "${var.project_name}-${var.environment}"
  network_mode          = "bridge" # Use bridge mode for EC2
  requires_compatibilities = ["EC2"]
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn        = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "${var.project_name}-backend"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-backend:latest"
      
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = 0 # Dynamic port mapping
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DATABASE_URL"
          value = "postgres://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}/${var.db_name}?sslmode=disable"
        },
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
      
      # Memory reservation for EC2 (leave room for the host OS)
      memoryReservation = 256
      
      # Health check for better container management
      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

# ECS Service - EC2 optimized
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count # 1 for Free Tier

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight           = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project_name}-backend"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.app,
    aws_iam_role_policy_attachment.ecs_task_execution_role,
    aws_autoscaling_group.ecs
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
} 