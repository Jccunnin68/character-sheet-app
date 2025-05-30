# EKS Cluster Configuration
# This file configures Amazon EKS (Elastic Kubernetes Service) to run containerized applications
# EKS provides managed Kubernetes control plane with automatic updates and high availability

# EKS Cluster
# The main EKS cluster resource that provides the Kubernetes control plane
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"  # Kubernetes version - use stable version

  # VPC Configuration - defines which subnets EKS can use
  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public_private[*].id)
    endpoint_private_access = true  # Allow private API access from within VPC
    endpoint_public_access  = true  # Allow public API access (restricted by CIDR blocks below)
    
    # Geo-restriction: Only allow access from US, Canada, and Europe IP ranges
    # These CIDR blocks cover major IP ranges for these regions
    public_access_cidrs = [
      # US IP ranges (major cloud providers and ISPs)
      "3.0.0.0/8",        # Amazon/AWS
      "4.0.0.0/8",        # Level 3 Communications
      "8.0.0.0/8",        # Level 3 Communications  
      "12.0.0.0/8",       # AT&T
      "24.0.0.0/8",       # Comcast
      "50.0.0.0/8",       # Comcast
      "63.0.0.0/8",       # Cogent
      "64.0.0.0/10",      # Various US providers
      "66.0.0.0/8",       # Sprint, Verizon
      "67.0.0.0/8",       # Comcast
      "68.0.0.0/8",       # Comcast, AT&T
      "69.0.0.0/8",       # Comcast, Road Runner
      "70.0.0.0/8",       # Comcast
      "71.0.0.0/8",       # Comcast
      "72.0.0.0/8",       # Comcast, Road Runner
      "73.0.0.0/8",       # Comcast, Verizon
      "74.0.0.0/8",       # Verizon, Optimum
      "75.0.0.0/8",       # Comcast, Verizon
      "76.0.0.0/8",       # Comcast
      "96.0.0.0/8",       # Comcast
      "98.0.0.0/8",       # Comcast
      "99.0.0.0/8",       # Comcast
      "173.0.0.0/8",      # Comcast, various
      "174.0.0.0/8",      # Cogent
      "184.0.0.0/8",      # Comcast, various
      "208.0.0.0/8",      # Various US ISPs
      
      # Canadian IP ranges
      "142.0.0.0/8",      # Canadian ISPs
      "206.0.0.0/8",      # Bell Canada, Rogers
      "209.0.0.0/8",      # Various Canadian ISPs
      
      # European IP ranges (major blocks)
      "2.0.0.0/8",        # European ISPs
      "5.0.0.0/8",        # European providers
      "31.0.0.0/8",       # European ISPs
      "37.0.0.0/8",       # European providers
      "46.0.0.0/8",       # European ISPs
      "62.0.0.0/8",       # European providers
      "77.0.0.0/8",       # European ISPs
      "78.0.0.0/8",       # European providers
      "79.0.0.0/8",       # European ISPs
      "80.0.0.0/8",       # European providers
      "81.0.0.0/8",       # European ISPs
      "82.0.0.0/8",       # European providers
      "83.0.0.0/8",       # European ISPs
      "84.0.0.0/8",       # European providers
      "85.0.0.0/8",       # European ISPs
      "86.0.0.0/8",       # European providers
      "87.0.0.0/8",       # European ISPs
      "88.0.0.0/8",       # European providers
      "89.0.0.0/8",       # European ISPs
      "90.0.0.0/8",       # European providers
      "91.0.0.0/8",       # European ISPs
      "92.0.0.0/8",       # European providers
      "93.0.0.0/8",       # European ISPs
      "94.0.0.0/8",       # European providers
      "95.0.0.0/8",       # European ISPs
      "151.0.0.0/8",      # European providers
      "176.0.0.0/8",      # European ISPs
      "178.0.0.0/8",      # European providers
      "188.0.0.0/8",      # European ISPs
      "193.0.0.0/8",      # European academic/research
      "194.0.0.0/8",      # European academic/research
      "195.0.0.0/8",      # European academic/research
    ]
  }

  # Enable EKS logging for monitoring and debugging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Ensure proper order of resource creation
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks"
    Environment = var.environment
  }
}

# EKS Node Group
# This manages the EC2 instances that will run the Kubernetes pods
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  
  # Use public subnets for cost optimization (avoid NAT gateway costs)
  # In production, you might want to use private subnets with NAT gateways
  subnet_ids = var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public[*].id

  # Node scaling configuration - now using variables
  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  # Update configuration for rolling updates
  update_config {
    max_unavailable = 1  # Allow one node to be unavailable during updates
  }

  # EC2 instance configuration - now using variables
  instance_types = var.node_instance_types
  ami_type       = "AL2_x86_64"  # Amazon Linux 2 AMI
  capacity_type  = "ON_DEMAND"   # Use On-Demand instances (can switch to SPOT for cost savings)
  disk_size      = 20            # EBS volume size in GB

  # Remote access configuration (optional - for debugging)
  dynamic "remote_access" {
    for_each = var.ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key = var.ssh_key_name
      source_security_group_ids = [aws_security_group.eks_nodes.id]
    }
  }

  # Ensure proper order of resource creation
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_group_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-node-group"
    Environment = var.environment
  }
}

# IAM Role for EKS Cluster
# This role allows EKS to manage AWS resources on your behalf
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  # Trust policy: allows EKS service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-cluster-role"
    Environment = var.environment
  }
}

# Attach required policy to EKS cluster role
# This policy grants EKS the necessary permissions to manage the cluster
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# IAM Role for EKS Node Group
# This role allows EC2 instances to join the EKS cluster and run pods
resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_name}-${var.environment}-eks-node-group-role"

  # Trust policy: allows EC2 service to assume this role
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
    Name        = "${var.project_name}-${var.environment}-eks-node-group-role"
    Environment = var.environment
  }
}

# Attach required policies to node group role
# These policies allow nodes to:
# 1. Join the EKS cluster
# 2. Configure pod networking
# 3. Pull container images from ECR
resource "aws_iam_role_policy_attachment" "eks_node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# Cross-account ECR access policy for nodes
# This allows EKS nodes to pull images from the shared ECR repository
resource "aws_iam_role_policy" "eks_cross_account_ecr" {
  name = "${var.project_name}-${var.environment}-cross-account-ecr"
  role = aws_iam_role.eks_node_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.shared_account_id}:repository/character-sheet-backend"
      }
    ]
  })
}

# Security Group for EKS Nodes
# Controls traffic to/from worker nodes
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-nodes"
  vpc_id      = aws_vpc.main.id

  # Allow nodes to communicate with each other
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # Allow pods to communicate with the cluster API Server
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Allow nodes to receive communication from managed node groups
  ingress {
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # SSH access (if key is provided)
  dynamic "ingress" {
    for_each = var.ssh_key_name != null ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]  # Restrict this in production
    }
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-nodes-sg"
    Environment = var.environment
  }
} 