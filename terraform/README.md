# Terraform Infrastructure

AWS infrastructure as code for the character sheet application using Terraform.

## Architecture

This Terraform configuration creates the following AWS resources:

### Networking
- VPC with public and private subnets across 2 AZs
- Internet Gateway and NAT Gateways for internet access
- Route tables and security groups

### Database
- RDS PostgreSQL instance in private subnets
- Database subnet group and parameter group
- Enhanced monitoring and automated backups

### Compute
- ECS Fargate cluster for containerized application
- Application Load Balancer for traffic distribution
- Auto Scaling and health checks

### Monitoring
- CloudWatch log groups for application logs
- RDS enhanced monitoring

## File Structure

```
terraform/
├── main.tf          # Main infrastructure (VPC, networking)
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── rds.tf          # Database infrastructure
├── ecs.tf          # Container orchestration
├── alb.tf          # Load balancer
└── README.md       # This file
```

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. Docker images pushed to ECR (for ECS deployment)

## Variables

### Required Variables
- `db_password` - Database master password
- `jwt_secret` - JWT secret for application authentication

### Optional Variables (with defaults)
- `aws_region` - AWS region (default: us-west-2)
- `environment` - Environment name (default: dev)
- `project_name` - Project name (default: character-sheet)
- `vpc_cidr` - VPC CIDR block (default: 10.0.0.0/16)
- `db_instance_class` - RDS instance class (default: db.t3.micro)
- `app_count` - Number of application instances (default: 2)

## Deployment

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Create terraform.tfvars
```hcl
db_password = "your-secure-database-password"
jwt_secret  = "your-jwt-secret-key"
environment = "dev"
```

### 3. Plan the deployment
```bash
terraform plan
```

### 4. Apply the infrastructure
```bash
terraform apply
```

### 5. Get outputs
```bash
terraform output
```

## Environment Variables for Application

After deployment, configure your application with:

```bash
DATABASE_URL="postgres://dbadmin:<password>@<rds-endpoint>:5432/character_sheets?sslmode=require"
JWT_SECRET="<your-jwt-secret>"
PORT="8080"
```

## ECR Setup (Required before ECS deployment)

1. Create ECR repository:
```bash
aws ecr create-repository --repository-name character-sheet-backend
```

2. Build and push Docker image:
```bash
# Get login token
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Build image
cd ../backend
docker build -t character-sheet-backend .

# Tag image
docker tag character-sheet-backend:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/character-sheet-backend:latest

# Push image
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/character-sheet-backend:latest
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Security Considerations

- Database is placed in private subnets with no public access
- Security groups restrict traffic to necessary ports only
- RDS encryption at rest is enabled
- Application secrets should be stored in AWS Secrets Manager (future enhancement)
- Consider enabling WAF for the load balancer in production

## Cost Optimization

- Uses t3.micro for RDS (Free Tier eligible)
- Fargate containers scale based on demand
- NAT Gateways are the primary cost driver (consider NAT instances for cost savings)

## Monitoring

- ECS Container Insights enabled
- RDS Enhanced Monitoring enabled
- Application logs sent to CloudWatch
- Consider adding CloudWatch alarms for production 