# Multi-Environment Setup Guide

Complete setup instructions for deploying the Character Sheet application across **4 separate AWS accounts** with automated CI/CD pipelines and comprehensive security.

> **Architecture Details**: See [README_EKS.md](README_EKS.md) for technical specifications and architecture diagrams.

## 📋 Prerequisites

### **Required AWS Accounts**
You need **4 separate AWS accounts**:
- **Shared Account**: ECR repository and shared resources
- **Dev Account**: Development environment
- **PreProd Account**: Pre-production environment  
- **Production Account**: Production environment

### **Required Tools**
- AWS CLI configured with appropriate credentials
- Terraform >= 1.6.0
- kubectl
- Docker
- Helm 3.x
- Git

## 🔐 IAM & OIDC Setup

### **Step 1: Create OIDC Providers**

Run this script in **each AWS account** (shared, dev, preprod, prod):

```bash
#!/bin/bash
# Set these variables for each account
ACCOUNT_TYPE="shared"  # Change to: shared, dev, preprod, or prod
GITHUB_REPO="YOUR_GITHUB_USERNAME/character-sheet-app"

echo "Setting up OIDC for ${ACCOUNT_TYPE} account..."

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create trust policy
cat << EOF > github-trust-policy-${ACCOUNT_TYPE}.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name GitHubActions-${ACCOUNT_TYPE} \
  --assume-role-policy-document file://github-trust-policy-${ACCOUNT_TYPE}.json

# Attach AdministratorAccess (customize as needed for production)
aws iam attach-role-policy \
  --role-name GitHubActions-${ACCOUNT_TYPE} \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo "✅ OIDC setup complete for ${ACCOUNT_TYPE} account"
echo "Role ARN: arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/GitHubActions-${ACCOUNT_TYPE}"
```

### **Step 2: Configure GitHub Secrets**

Add these secrets to your GitHub repository (**Settings → Secrets and variables → Actions**):

#### **Account Access Secrets**
```bash
# Shared account access
AWS_SHARED_ROLE_TO_ASSUME: arn:aws:iam::SHARED_ACCOUNT_ID:role/GitHubActions-shared
SHARED_ACCOUNT_ID: 123456789012

# Dev account access  
AWS_DEV_ROLE_TO_ASSUME: arn:aws:iam::DEV_ACCOUNT_ID:role/GitHubActions-dev
DEV_ACCOUNT_ID: 123456789013

# PreProd account access
AWS_PREPROD_ROLE_TO_ASSUME: arn:aws:iam::PREPROD_ACCOUNT_ID:role/GitHubActions-preprod  
PREPROD_ACCOUNT_ID: 123456789014

# Production account access
AWS_PROD_ROLE_TO_ASSUME: arn:aws:iam::PROD_ACCOUNT_ID:role/GitHubActions-prod
PROD_ACCOUNT_ID: 123456789015
```

#### **Application Secrets**
```bash
# Dev environment secrets
DEV_DB_PASSWORD: your-secure-dev-db-password
DEV_JWT_SECRET: your-32-character-dev-jwt-secret-key

# PreProd environment secrets
PREPROD_DB_PASSWORD: your-secure-preprod-db-password
PREPROD_JWT_SECRET: your-32-character-preprod-jwt-secret

# Production environment secrets
PROD_DB_PASSWORD: your-highly-secure-production-password
PROD_JWT_SECRET: your-32-character-production-jwt-secret
PROD_API_KEY: your-optional-production-api-key
```

> **Security Note**: Use strong, unique passwords and secrets for each environment. Consider using a password manager to generate and store these securely.

## 🚀 Deployment Process

### **Step 1: Prepare Repository**

```bash
# Clone and prepare repository
git clone https://github.com/YOUR_USERNAME/character-sheet-app.git
cd character-sheet-app

# Create release branch for preprod deployments
git checkout -b release
git push origin release

# Return to main branch
git checkout main
```

### **Step 2: Update Configuration Files**

**Edit `terraform/shared-infrastructure/terraform.tfvars`**:
```hcl
# Replace with your actual AWS account IDs
dev_account_id = "123456789013"
preprod_account_id = "123456789014"  
prod_account_id = "123456789015"

# Optional: Customize shared infrastructure
ecr_repository_name = "character-sheet-backend"
region = "us-west-2"
```

### **Step 3: Deploy Shared Infrastructure**

Deploy the shared ECR repository and networking first:

```bash
# Option A: GitHub Actions (Recommended)
# 1. Go to Actions → "Deploy Networking and Shared Infrastructure"
# 2. Click "Run workflow"  
# 3. Select "apply"
# 4. Click "Run workflow"

# Option B: Manual deployment
cd terraform/shared-infrastructure
terraform init
terraform plan
terraform apply
```

After deployment, the workflow will automatically:
- Create ECR repository in shared account
- Set up cross-account access policies
- Update environment configurations with ECR URLs

### **Step 4: Deploy Environment Infrastructure**

Deploy infrastructure to each environment:

#### **Deploy to Dev**
```bash
# GitHub Actions
Actions → Deploy Infrastructure → environment: dev, action: apply

# Manual alternative
cd terraform
cp environments/dev/terraform.tfvars .
# Update placeholders with actual values from GitHub secrets
terraform init
terraform apply
```

#### **Deploy to PreProd** 
```bash
# GitHub Actions
Actions → Deploy Infrastructure → environment: preprod, action: apply

# Manual alternative  
cd terraform
cp environments/preprod/terraform.tfvars .
# Update placeholders with actual values from GitHub secrets
terraform init
terraform apply
```

#### **Deploy to Production**
```bash
# GitHub Actions
Actions → Deploy Infrastructure → environment: prod, action: apply

# Manual alternative
cd terraform  
cp environments/prod/terraform.tfvars .
# Update placeholders with actual values from GitHub secrets
terraform init
terraform apply
```

### **Step 5: Test Application Deployments**

Once infrastructure is ready, test the application deployment workflow:

#### **Test Dev Deployment**
```bash
# Make a small change and push to main
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger dev deployment"
git push origin main

# This should automatically deploy to Dev environment
# Check Actions tab for deployment progress
```

#### **Test PreProd Deployment**  
```bash
# Merge main to release branch
git checkout release
git merge main
git push origin release

# This should automatically deploy to PreProd environment
# Check Actions tab for deployment progress
```

#### **Test Production Deployment**
```bash
# Use manual workflow for production
# Actions → Deploy Applications → target_environment: prod, source_image_tag: latest-preprod
```

## 🔧 Configuration Reference

### **Environment-Specific Settings**

#### **Development Environment**
```hcl
# terraform/environments/dev/terraform.tfvars
environment = "dev"
node_count = 1
max_nodes = 2
instance_type = "t3.medium"
db_instance_class = "db.t3.micro"
enable_nat_gateway = false
backup_retention_period = 0
```

#### **PreProd Environment**  
```hcl
# terraform/environments/preprod/terraform.tfvars
environment = "preprod"
node_count = 2
max_nodes = 3  
instance_type = "t3.large"
db_instance_class = "db.t3.small"
enable_nat_gateway = false
backup_retention_period = 0
```

#### **Production Environment**
```hcl
# terraform/environments/prod/terraform.tfvars
environment = "prod"
node_count = 3
max_nodes = 6
instance_type = "m5.large"
db_instance_class = "db.t3.medium"
enable_nat_gateway = true
backup_retention_period = 7
multi_az = true
```

### **GitHub Actions Workflow Configuration**

The deployment uses these workflows:

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `deploy-infrastructure.yml` | Deploy/update infrastructure | Manual only |
| `deploy-applications.yml` | Deploy applications | Branch-based + Manual |
| `deploy-networking.yml` | Deploy shared infrastructure | Manual only |
| `pr-validation.yml` | Validate pull requests | Automatic |

## 🔍 Verification & Testing

### **Infrastructure Verification**

After each deployment, verify the infrastructure:

```bash
# Check EKS cluster
aws eks describe-cluster --name character-sheet-{env}-eks --region us-west-2

# Check RDS instance  
aws rds describe-db-instances --db-instance-identifier character-sheet-{env}-db

# Check ECR repository (shared account)
aws ecr describe-repositories --repository-names character-sheet-backend
```

### **Application Health Checks**

```bash  
# Get application URL
kubectl get ingress character-sheet-ingress -n character-sheet

# Test health endpoint
curl -f https://your-alb-dns/health

# Check pod status
kubectl get pods -n character-sheet
```

### **Secrets Verification**

```bash
# Verify External Secrets are syncing
kubectl get externalsecrets -n character-sheet

# Check created Kubernetes secrets
kubectl get secrets -n character-sheet
```

## 🛠️ Troubleshooting

### **Common Issues**

#### **1. OIDC Provider Issues**
```bash
# Error: OIDC provider already exists
# Solution: Skip creation or delete existing provider
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com
```

#### **2. GitHub Secrets Not Working**  
- Verify account IDs are correct
- Check IAM role ARNs match the secrets
- Ensure GitHub repository has access to secrets

#### **3. Terraform State Conflicts**
```bash
# If using shared state, ensure different state keys per environment
terraform init -backend-config="key=character-sheet/dev/terraform.tfstate"
```

#### **4. ECR Permission Issues**
```bash
# Verify cross-account ECR policies in shared account
aws ecr get-repository-policy --repository-name character-sheet-backend
```

### **Monitoring Deployment Progress**

```bash
# Watch GitHub Actions
# Go to repository → Actions tab → Select running workflow

# Monitor Kubernetes deployments
kubectl get events -n character-sheet --sort-by='.lastTimestamp'

# Check application logs
kubectl logs -f deployment/backend-deployment -n character-sheet
```

## 📚 Next Steps

After successful deployment:

1. **Configure Monitoring**: Set up CloudWatch dashboards and alerts
2. **Set Up Branch Protection**: Configure GitHub branch protection rules  
3. **Review Security**: Audit IAM permissions and security groups
4. **Test Disaster Recovery**: Practice backup and restore procedures
5. **Document Operations**: Create runbooks for common operational tasks

## 🔗 Related Documentation

- **[README.md](README.md)** - Project overview and quick start
- **[README_EKS.md](README_EKS.md)** - Technical architecture details
- **[WORKFLOW_SEPARATION.md](WORKFLOW_SEPARATION.md)** - CI/CD workflow guide
- **[SECRETS_MANAGER_SETUP.md](SECRETS_MANAGER_SETUP.md)** - AWS Secrets Manager details

---

**Need Help?** Check the troubleshooting section above or review the detailed architecture in [README_EKS.md](README_EKS.md). 