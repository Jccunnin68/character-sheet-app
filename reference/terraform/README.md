# ECS Reference Implementation - Terraform Configuration
# =====================================================

This directory contains a **complete, working Terraform configuration** for the ECS reference implementation. It's optimized for **AWS Free Tier** usage and provides a cost-effective alternative to the multi-environment EKS setup.

## 🏗️ Architecture Overview

### **Infrastructure Components**
- **ECS on EC2**: Container orchestration with t3.micro instances (Free Tier)
- **Application Load Balancer**: Public-facing load balancer for the backend API
- **RDS PostgreSQL**: Database on db.t3.micro (Free Tier)
- **S3 + CloudFront**: Frontend hosting and CDN
- **VPC**: Multi-AZ networking with optional NAT Gateway
- **VPC Endpoints**: Cost optimization for ECR and S3 access

### **Cost Optimization Features**
- ✅ No NAT Gateway by default (saves $32/month)
- ✅ Public subnets for ECS instances (Free Tier friendly)
- ✅ VPC endpoints to reduce data transfer costs
- ✅ Minimal CloudWatch log retention
- ✅ No enhanced monitoring or encryption features

## 📁 File Structure

```
reference/terraform/
├── main.tf              # Provider configuration and data sources
├── variables.tf         # All variable definitions with defaults
├── terraform.tfvars.example  # Example configuration file
├── outputs.tf           # Important resource outputs
├── networking.tf        # VPC, subnets, routing, VPC endpoints
├── database.tf          # RDS PostgreSQL configuration
├── ecs.tf              # ECS cluster, services, and task definitions
├── alb.tf              # Application Load Balancer configuration
├── s3-cloudfront.tf    # Frontend hosting (S3 + CloudFront)
├── user_data.sh        # EC2 instance initialization script
└── README.md           # This file
```

## 🚀 Quick Start

### **1. Prerequisites**
- AWS CLI configured with credentials
- Terraform >= 1.0 installed
- ECR repository created for backend images

### **2. Configure Variables**
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Required variables to update:**
```hcl
db_password = "your-secure-password-change-this"
jwt_secret  = "your-32-character-jwt-secret-key"
```

### **3. Deploy Infrastructure**
```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

### **4. Deploy Application**
```bash
# Build and push backend image to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d'/' -f1)

cd ../../backend
docker build -t character-sheet-backend .
docker tag character-sheet-backend:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Deploy frontend to S3
cd ../frontend
npm run build
aws s3 sync build/ s3://$(terraform output -raw s3_bucket_name)/
```

## 💰 Cost Breakdown

### **Free Tier (12 months)**
| Service | Free Tier Allowance | Reference Usage |
|---------|---------------------|-----------------|
| EC2 | 750 hours t3.micro | 1 instance (744 hours/month) |
| RDS | 750 hours db.t3.micro + 20GB | 1 instance + 20GB |
| S3 | 5GB storage + 20K GET + 2K PUT | ~100MB + minimal requests |
| CloudFront | 1TB transfer + 10M requests | Typical small app usage |
| CloudWatch Logs | 5GB ingestion + storage | 3-day retention |

### **Estimated Monthly Costs**
- **Within Free Tier**: $0-8/month (data transfer overages)
- **With NAT Gateway**: $32-40/month
- **After Free Tier**: $35-50/month

## ⚙️ Configuration Options

### **Cost vs. Features Trade-offs**

#### **Maximum Free Tier (Default)**
```hcl
enable_nat_gateway = false
db_instance_class = "db.t3.micro"
instance_type = "t3.micro"
log_retention_days = 3
```

#### **Enhanced Security (Additional Cost)**
```hcl
enable_nat_gateway = true  # +$32/month
db_instance_class = "db.t3.small"  # +$13/month
log_retention_days = 30  # +$2/month
```

## 📊 Outputs

After deployment, Terraform provides these important outputs:

```bash
# Application URLs
terraform output application_urls

# Database connection
terraform output database_url

# Cost estimation
terraform output estimated_monthly_cost

# All outputs
terraform output
```

## 🔧 Common Operations

### **Scale ECS Service**
```bash
# Update desired count in terraform.tfvars
app_count = 2

# Apply changes
terraform apply
```

### **Update Application**
```bash
# Build new image with version tag
docker build -t character-sheet-backend .
docker tag character-sheet-backend:latest $(terraform output -raw ecr_repository_url):v1.1
docker push $(terraform output -raw ecr_repository_url):v1.1

# Update ECS service to use new image
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_id) \
  --service $(terraform output -raw ecs_service_name) \
  --force-new-deployment
```

### **Access Logs**
```bash
# ECS service logs
aws logs tail /ecs/character-sheet-prod --follow

# RDS logs
aws rds describe-db-log-files --db-instance-identifier character-sheet-prod
```

## 🔍 Troubleshooting

### **Common Issues**

#### **ECS Tasks Won't Start**
```bash
# Check ECS service events
aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_id) --services $(terraform output -raw ecs_service_name)

# Check task definition
aws ecs describe-task-definition --task-definition character-sheet-prod
```

#### **Database Connection Issues**
```bash
# Test database connectivity from ECS instance
aws ssm start-session --target <instance-id>
psql "$(terraform output -raw database_url)"
```

#### **High Costs**
- Check if NAT Gateway is enabled (`enable_nat_gateway = true`)
- Review CloudWatch logs retention period
- Monitor data transfer costs

## 🔄 Migration Paths

### **From ECS to EKS (Current Setup)**
1. Review `MULTI_ENVIRONMENT_SETUP.md` in the root directory
2. Set up 4 AWS accounts (Shared, Dev, PreProd, Production)
3. Deploy shared infrastructure first
4. Migrate application to Kubernetes manifests

### **From Single Environment to Multi-Environment ECS**
1. Create environment-specific terraform.tfvars files
2. Use Terraform workspaces or separate state files
3. Implement CI/CD pipelines for each environment

## 📚 Additional Resources

### **Documentation**
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Free Tier Details](https://aws.amazon.com/free/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### **Cost Optimization**
- [AWS Cost Calculator](https://calculator.aws/#/)
- [AWS Trusted Advisor](https://aws.amazon.com/support/trustedadvisor/)
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)

---

**Note**: This reference implementation demonstrates **cost-effective AWS deployment patterns** and serves as an **educational alternative** to the enterprise-grade multi-environment setup. Choose based on your specific requirements for cost, complexity, and scale. 