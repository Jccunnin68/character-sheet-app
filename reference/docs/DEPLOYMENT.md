# Deployment Guide

This guide covers deploying the Character Sheet application to AWS using GitHub Actions, optimized for the **AWS Free Tier** using **ECS on EC2**.

## Prerequisites

1. AWS Account with Free Tier eligibility
2. GitHub repository with the codebase  
3. AWS ECR for container images (Free Tier: 500 MB storage)

## Free Tier Configuration

This project is **optimized for AWS Free Tier** using **ECS on EC2** instead of Fargate for maximum Free Tier utilization:

### Free Tier Limits (12 months)
- **EC2 Instances**: 750 hours t3.micro/month (1 instance = 24/7 coverage)
- **RDS**: 750 hours db.t3.micro + 20GB storage
- **S3**: 5GB storage, 20K GET requests, 2K PUT requests  
- **CloudFront**: 1TB data transfer, 10M HTTP/HTTPS requests
- **CloudWatch Logs**: 5GB ingestion + 5GB storage
- **VPC**: No charges for basic VPC resources

### Cost-Optimized Settings
- **ECS on EC2**: Uses t3.micro instances (750 hours Free Tier vs. limited Fargate)
- **NAT Gateway**: Disabled by default (saves ~$32/month)
- **RDS Encryption**: Disabled (not included in Free Tier)
- **Enhanced Monitoring**: Disabled (costs extra)
- **Container Insights**: Disabled (costs extra)
- **S3 Versioning**: Disabled (saves storage)
- **Log Retention**: 3 days (minimal)

### Architecture Benefits
- **Better Free Tier Usage**: EC2 instances get 750 hours/month vs. Fargate's limited vCPU seconds
- **Self-Healing**: Auto Scaling Group maintains single instance
- **Dynamic Port Mapping**: Bridge networking with ALB integration
- **SSH Access**: Optional SSH access for debugging
- **Resource Sharing**: Single EC2 instance can run multiple containers

## GitHub Secrets Setup

Configure the following secrets in your GitHub repository (`Settings > Secrets and variables > Actions`):

### Required AWS Secrets
```
AWS_ACCESS_KEY_ID=<your-aws-access-key>
AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
DB_PASSWORD=<secure-database-password>
JWT_SECRET=<secure-jwt-secret-32-chars-minimum>
```

### Frontend Deployment Secrets
```
REACT_APP_API_URL=http://<your-alb-dns-name>
S3_BUCKET_NAME=<s3-bucket-name-from-terraform-output>
CLOUDFRONT_DISTRIBUTION_ID=<cloudfront-distribution-id>
CLOUDFRONT_DOMAIN=<cloudfront-domain-name>
```

## Deployment Process

The GitHub Actions workflow automatically handles deployment in this order:

### 1. Test Phase
- Runs frontend tests (React)
- Runs backend tests (Go)

### 2. Build Phase
- **Backend**: Builds Docker image and pushes to ECR
- **Frontend**: Builds React application for production

### 3. Infrastructure Phase
- Deploys/updates AWS infrastructure using Terraform
- Creates VPC, RDS, ECS, ALB, S3, CloudFront

### 4. Application Deployment
- **Backend**: Deploys to ECS Fargate with new Docker image
- **Frontend**: Deploys to S3 and invalidates CloudFront cache

### 5. Database Migration
- Runs database schema initialization
- Connects to RDS instance and applies migrations

### 6. Smoke Tests
- Health check on backend API
- Basic API endpoint testing
- Frontend availability check

## Initial Setup Steps

### 1. Create ECR Repository
```bash
aws ecr create-repository --repository-name character-sheet-backend --region us-west-2
```

### 2. Update Task Definition
Edit `.github/task-definition.json` and replace `ACCOUNT_ID` with your AWS account ID.

### 3. Configure Free Tier Variables
Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and update:

```hcl
# Free Tier Optimized Configuration
enable_nat_gateway = false  # Keep false for Free Tier
app_count = 1              # Single task for Free Tier
db_instance_class = "db.t3.micro"
db_password = "your-secure-password"
jwt_secret = "your-32-character-jwt-secret"
```

### 4. First Deployment
1. Push code to `main` branch
2. GitHub Actions will automatically trigger
3. Monitor deployment in Actions tab
4. Note the outputs for frontend configuration

## Free Tier Architecture

```
Internet Gateway
    |
Public Subnets (2 AZs)
    |
    ├── ALB (Application Load Balancer)
    ├── EC2 Instance (t3.micro) running ECS Agent
    │   └── Docker Containers (dynamic port mapping)
    └── RDS (publicly accessible within VPC)
    
CloudFront → S3 Bucket (Frontend)
```

**Key differences from Fargate:**
- Uses EC2 instances (t3.micro) instead of Fargate tasks
- Bridge networking with dynamic port assignment
- Auto Scaling Group provides instance management
- Better Free Tier hour utilization (750 hours vs. limited vCPU seconds)
- Optional SSH access for debugging

## Production Configuration

### Environment Variables
The application uses these environment variables in production:

**Backend (ECS):**
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - JWT signing secret
- `PORT` - Application port (8080)

**Frontend (Build time):**
- `REACT_APP_API_URL` - Backend API URL

### Resource Sizing (Free Tier)
- **EC2**: t3.micro instance (1 vCPU, 1GB RAM) with ECS agent
- **RDS**: db.t3.micro, 20GB storage
- **CloudWatch**: 3-day log retention
- **Auto Scaling Group**: min/max/desired = 1 instance

## Manual Operations

### Trigger Deployment
```bash
# Via GitHub CLI
gh workflow run deploy.yml

# Or push to main branch  
git push origin main
```

### Check Free Tier Usage
```bash
# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:AmazonECSManaged,Values=true"

# Check ECS cluster capacity
aws ecs describe-clusters --clusters character-sheet-prod

# Check RDS hours 
aws rds describe-db-instances --db-instance-identifier character-sheet-prod

# Monitor costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost
```

### Access Application
- **Frontend**: `https://<cloudfront-domain>`
- **Backend API**: `http://<alb-dns-name>` 
- **Health Check**: `http://<alb-dns-name>/health`

## Troubleshooting

### Common Issues

**1. EC2 Instance Fails to Start**
- Check CloudWatch logs: `/ecs/character-sheet-prod`
- Verify environment variables and secrets
- Ensure EC2 instance has public IP assignment

**2. Database Connection Issues**
- Verify RDS security group allows ECS connections
- Check DATABASE_URL format (note: sslmode=disable for Free Tier)
- Ensure RDS is publicly accessible

**3. Free Tier Limits Exceeded**
- Monitor EC2 instance hours (limit: 750 hours/month = 24/7 for 1 instance)
- Check container memory usage on t3.micro
- Monitor S3 request counts

**4. EC2 Instance Issues**
- SSH into instance: `aws ssm start-session --target <instance-id>`
- Check ECS agent: `sudo docker ps` and `sudo systemctl status ecs`
- Check container logs: `sudo docker logs <container-id>`

## Cost Monitoring

### Free Tier Limits Tracking
```bash
# Check EC2 usage
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,LaunchTime]'

# Check ECS container status
aws ecs list-tasks --cluster character-sheet-prod

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names character-sheet-ecs-asg
```

### Monthly Cost Estimate
**Free Tier Optimized (enable_nat_gateway=false):**
- EC2 t3.micro: $0 (within Free Tier - 750 hours)
- RDS db.t3.micro: $0 (within Free Tier - 750 hours) 
- S3 + CloudFront: $0-3
- **Total: $0-3/month**

**With NAT Gateway (enable_nat_gateway=true):**
- NAT Gateway: ~$32/month
- Other services: $0-8
- **Total: $32-40/month**

## Scaling Beyond Free Tier

When ready to scale for production:

1. **Multiple Instances**: Increase Auto Scaling Group size
2. **Larger Instances**: Use t3.small or t3.medium instances
3. **Enable NAT Gateway**: Set `enable_nat_gateway = true` for private subnets
4. **Upgrade RDS**: Use larger instance class
5. **Enable monitoring**: Turn on Container Insights, Enhanced Monitoring
6. **Add auto-scaling**: Configure dynamic scaling policies

## Security Considerations

- Database in VPC with restricted security groups
- ECS tasks use public IPs but security groups limit access
- S3 bucket has public access blocked
- CloudFront serves content over HTTPS
- Secrets stored in GitHub repository secrets

## Cleanup

To destroy all resources:
```bash
cd terraform
terraform destroy -auto-approve
```

**Note**: Empty S3 buckets before destruction and verify all resources are deleted to avoid charges. 