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
      # United States IP ranges (major blocks)
      "3.0.0.0/8",       # Amazon/AWS US
      "4.0.0.0/6",       # Level 3 Communications US
      "8.0.0.0/7",       # Level 3 Communications US
      "12.0.0.0/6",      # AT&T US
      "16.0.0.0/4",      # Hewlett-Packard US
      "24.0.0.0/5",      # Comcast US
      "32.0.0.0/3",      # Major US ISPs
      "64.0.0.0/2",      # Major US ISPs
      "128.0.0.0/2",     # Major US ISPs
      "192.0.0.0/2",     # Major US ISPs
      
      # Canada IP ranges
      "142.0.0.0/8",     # Canadian ISPs
      "206.0.0.0/7",     # Canadian ISPs
      "208.0.0.0/4",     # North American ISPs (includes Canada)
      
      # Europe IP ranges (major blocks)
      "2.0.0.0/8",       # European ISPs
      "5.0.0.0/8",       # European ISPs
      "31.0.0.0/8",      # European ISPs
      "37.0.0.0/8",      # European ISPs
      "46.0.0.0/8",      # European ISPs
      "62.0.0.0/8",      # European ISPs
      "77.0.0.0/8",      # European ISPs
      "78.0.0.0/7",      # European ISPs
      "80.0.0.0/4",      # European ISPs
      "109.0.0.0/8",     # European ISPs
      "151.0.0.0/8",     # European ISPs
      "176.0.0.0/4",     # European ISPs
      "193.0.0.0/8",     # European ISPs
      "194.0.0.0/7",     # European ISPs
      "213.0.0.0/8",     # European ISPs
    ]
    
    security_group_ids = [aws_security_group.eks_cluster.id]
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
# Managed worker nodes that will run the actual application pods
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  
  # Use public subnets for cost optimization (avoid NAT gateway costs)
  # In production, you might want to use private subnets with NAT gateways
  subnet_ids = var.enable_nat_gateway ? aws_subnet.private[*].id : aws_subnet.public[*].id

  # Node scaling configuration
  scaling_config {
    desired_size = 2  # Number of nodes to maintain
    max_size     = 4  # Maximum nodes during scaling
    min_size     = 1  # Minimum nodes (cost optimization)
  }

  # Update configuration for rolling updates
  update_config {
    max_unavailable = 1  # Allow one node to be unavailable during updates
  }

  # EC2 instance configuration
  instance_types = ["t3.small"]  # Cost-effective instance type
  ami_type       = "AL2_x86_64"  # Amazon Linux 2 AMI
  capacity_type  = "ON_DEMAND"   # Use On-Demand instances (can switch to SPOT for cost savings)
  disk_size      = 20            # EBS volume size in GB

  # Remote access configuration (optional - for debugging)
  remote_access {
    ec2_ssh_key = var.ssh_key_name  # SSH key for node access (create via AWS console)
    source_security_group_ids = [aws_security_group.eks_nodes.id]
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

# Security Group for EKS Cluster
# Controls network access to the EKS API server
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project_name}-${var.environment}-eks-cluster-"
  vpc_id      = aws_vpc.main.id

  # Allow HTTPS traffic from nodes to cluster API
  ingress {
    description = "Node to cluster API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
    Environment = var.environment
  }
}

# Security Group for EKS Nodes
# Controls network access to worker nodes
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-nodes-"
  vpc_id      = aws_vpc.main.id

  # Allow nodes to communicate with each other
  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Allow pods to communicate with cluster API
  ingress {
    description = "Cluster API to node communication"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Allow Application Load Balancer to reach services
  ingress {
    description = "ALB to nodes"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH access for debugging (restricted to geo-locations)
  ingress {
    description = "SSH access from allowed regions"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Use same geo-restricted CIDR blocks as EKS API access
    cidr_blocks = [
      # United States
      "3.0.0.0/8", "4.0.0.0/6", "8.0.0.0/7", "12.0.0.0/6", "16.0.0.0/4",
      "24.0.0.0/5", "32.0.0.0/3", "64.0.0.0/2", "128.0.0.0/2", "192.0.0.0/2",
      # Canada
      "142.0.0.0/8", "206.0.0.0/7", "208.0.0.0/4",
      # Europe
      "2.0.0.0/8", "5.0.0.0/8", "31.0.0.0/8", "37.0.0.0/8", "46.0.0.0/8",
      "62.0.0.0/8", "77.0.0.0/8", "78.0.0.0/7", "80.0.0.0/4", "109.0.0.0/8",
      "151.0.0.0/8", "176.0.0.0/4", "193.0.0.0/8", "194.0.0.0/7", "213.0.0.0/8"
    ]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
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