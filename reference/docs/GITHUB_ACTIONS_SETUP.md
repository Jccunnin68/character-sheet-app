# GitHub Actions CI/CD Setup Guide

This guide explains the GitHub Actions workflows for the Character Sheet application, providing automated deployment, validation, and testing capabilities.

## 🔄 Workflow Overview

### **Three Main Workflows**

1. **🚀 Deploy Application Update** (`deploy-app-update.yml`)
   - **Purpose**: Fast application updates without infrastructure changes
   - **Triggers**: Push to `main` with changes to app code
   - **Duration**: ~5-10 minutes

2. **🏗️ Deploy Full Infrastructure** (`deploy-infrastructure.yml`)
   - **Purpose**: Complete infrastructure deployment with Terraform
   - **Triggers**: Push to `main` with Terraform changes or manual dispatch
   - **Duration**: ~15-25 minutes

3. **🔍 Pull Request Validation** (`pr-validation.yml`)
   - **Purpose**: Validate code changes before merging
   - **Triggers**: Pull requests to `main`
   - **Duration**: ~5-8 minutes

## 📋 Workflow Details

### **1. Deploy Application Update**

**File**: `.github/workflows/deploy-app-update.yml`

**Features**:
- ✅ Builds and pushes Docker images to ECR
- ✅ Updates Kubernetes deployments with new image tags
- ✅ Handles External Secrets Operator configuration
- ✅ Performs health checks and deployment verification
- ✅ Supports manual dispatch with custom image tags

**Trigger Paths**:
```yaml
paths:
  - 'backend/**'
  - 'frontend/**'
  - 'k8s/**'
  - 'docker-compose.yml'
  - 'Dockerfile*'
```

**Workflow Steps**:
1. **Build & Push**: Docker image to ECR with commit hash tag
2. **Configure**: kubectl and validate cluster access
3. **Install**: External Secrets Operator (if needed)
4. **Deploy**: Updated Kubernetes manifests
5. **Verify**: Health checks and deployment status

### **2. Deploy Full Infrastructure**

**File**: `.github/workflows/deploy-infrastructure.yml`

**Features**:
- ✅ Terraform plan, apply, or destroy operations
- ✅ Creates ECR repositories automatically
- ✅ Installs AWS Load Balancer Controller
- ✅ Deploys complete application stack
- ✅ Supports multiple environments (dev/staging/prod)

**Manual Dispatch Options**:
- **Environment**: dev, staging, prod
- **Terraform Action**: plan, apply, destroy
- **Skip Application Deploy**: Terraform only option

**Workflow Jobs**:
1. **Terraform**: Infrastructure provisioning
2. **Deploy Application**: Complete app deployment
3. **Summary**: Deployment status and next steps

### **3. Pull Request Validation**

**File**: `.github/workflows/pr-validation.yml`

**Features**:
- ✅ Terraform format checking and validation
- ✅ Kubernetes manifest validation with kubeval
- ✅ Docker build testing
- ✅ Security scanning with Trivy
- ✅ Automatic PR comments with Terraform plan

**Validation Steps**:
1. **Terraform**: Format, validate, and plan
2. **Kubernetes**: Manifest validation and kustomize testing
3. **Docker**: Build testing for all services
4. **Security**: Secret detection and misconfiguration scanning

## 🔐 Required GitHub Secrets

### **AWS Authentication (OIDC Recommended)**

#### **Option A: OIDC (Recommended)**
```bash
AWS_ROLE_TO_ASSUME: arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole
```

#### **Option B: Access Keys (Less Secure)**
```bash
AWS_ACCESS_KEY_ID: your-access-key-id
AWS_SECRET_ACCESS_KEY: your-secret-access-key
```

### **Application Secrets**
```bash
DB_PASSWORD: your-secure-database-password
JWT_SECRET: your-32-character-jwt-secret-key
SSH_KEY_NAME: your-ec2-key-pair-name (optional)
API_KEY: your-api-key-for-integrations (optional)
```

## 🏗️ Initial Setup

### **1. Create AWS IAM Role for GitHub Actions**

**Create IAM Role**:
```bash
# Create trust policy for GitHub OIDC
cat << EOF > github-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/character-sheet-app:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-trust-policy.json
```

**Attach Policies**:
```bash
# Attach required policies
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Note: In production, use more restrictive policies
```

### **2. Set Up OIDC Provider** 

```bash
# Create OIDC provider (if not exists)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### **3. Configure GitHub Repository Secrets**

**Navigate to**: Repository → Settings → Secrets and variables → Actions

**Add Repository Secrets**:
```bash
AWS_ROLE_TO_ASSUME: arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole
DB_PASSWORD: your-secure-password-here
JWT_SECRET: your-32-character-secret-key-here
SSH_KEY_NAME: your-key-pair-name (optional)
API_KEY: your-api-key (optional)
```

## 📚 Usage Examples

### **Deploying Application Updates**

**Automatic Trigger** (when pushing to main):
```bash
git add backend/main.go
git commit -m "feat: add new API endpoint"
git push origin main
# Workflow automatically triggers
```

**Manual Trigger**:
1. Go to **Actions** tab in GitHub
2. Select **Deploy Application Update**
3. Click **Run workflow**
4. Choose environment and image tag
5. Click **Run workflow**

### **Full Infrastructure Deployment**

**Manual Trigger**:
1. Go to **Actions** tab in GitHub
2. Select **Deploy Full Infrastructure**
3. Click **Run workflow**
4. Configure options:
   - **Environment**: prod
   - **Terraform Action**: apply
   - **Skip Application Deploy**: false
5. Click **Run workflow**

### **Testing Pull Requests**

**Automatic** (when creating PR):
```bash
git checkout -b feature/new-feature
git add terraform/main.tf
git commit -m "feat: add new AWS resource"
git push origin feature/new-feature
# Create PR - validation workflow runs automatically
```

## 🔧 Workflow Customization

### **Environment Variables**

**Global Configuration** (`.github/workflows/*.yml`):
```yaml
env:
  AWS_REGION: us-west-2              # Change region
  ECR_REPOSITORY: character-sheet-backend
  EKS_CLUSTER_NAME: character-sheet-prod-eks
  TERRAFORM_VERSION: 1.6.0          # Update Terraform version
```

### **Multi-Environment Support**

**Update Workflow** to support different environments:
```yaml
# In deploy-infrastructure.yml
env:
  EKS_CLUSTER_NAME: character-sheet-${{ github.event.inputs.environment }}-eks
  
# In deploy-app-update.yml
env:
  EKS_CLUSTER_NAME: character-sheet-${{ github.event.inputs.environment || 'prod' }}-eks
```

### **Custom Triggers**

**Add Custom Paths**:
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
      - 'k8s/**'
      - 'custom-path/**'  # Add your custom path
```

**Add Schedule Trigger**:
```yaml
on:
  schedule:
    - cron: '0 2 * * 1'  # Run every Monday at 2 AM
  push:
    branches: [main]
```

## 📊 Monitoring and Debugging

### **Workflow Status**

**Check Deployment Status**:
```bash
# From workflow logs or manually
kubectl get all -n character-sheet
kubectl get externalsecrets -n character-sheet
kubectl logs -f deployment/backend-deployment -n character-sheet
```

**Get Application URL**:
```bash
kubectl get ingress character-sheet-ingress -n character-sheet \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### **Common Issues**

**1. AWS Permission Denied**:
```bash
# Check IAM role trust policy
aws iam get-role --role-name GitHubActionsRole

# Verify OIDC provider
aws iam list-open-id-connect-providers
```

**2. Terraform State Lock**:
```bash
# If Terraform state is locked, force unlock
terraform force-unlock LOCK_ID -force
```

**3. External Secrets Not Syncing**:
```bash
# Check External Secrets Operator logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Check service account annotations
kubectl describe serviceaccount external-secrets-sa -n character-sheet
```

## 🚨 Security Best Practices

### **Secrets Management**
- ✅ Use GitHub repository secrets for sensitive data
- ✅ Use OIDC instead of access keys when possible
- ✅ Implement least privilege IAM policies
- ✅ Rotate secrets regularly

### **Workflow Security**
- ✅ Pin action versions to specific tags
- ✅ Use `permissions` to limit token scope
- ✅ Review workflow logs for sensitive data exposure
- ✅ Enable branch protection rules

### **Infrastructure Security**
- ✅ Use Terraform state encryption
- ✅ Implement resource tagging strategy
- ✅ Enable CloudTrail logging
- ✅ Regular security scanning with Trivy

## 📈 Performance Optimization

### **Workflow Speed**
- ⚡ **Application Updates**: 5-10 minutes (vs 15-25 for full deployment)
- ⚡ **Parallel Jobs**: Multiple validation jobs run concurrently
- ⚡ **Docker Layer Caching**: Reuse layers between builds
- ⚡ **Conditional Steps**: Skip unnecessary steps when possible

### **Cost Optimization**
- 💰 **Spot Instances**: Consider for development environments
- 💰 **Resource Limits**: Set appropriate timeouts for jobs
- 💰 **Scheduled Deployments**: Deploy during off-peak hours
- 💰 **Environment Cleanup**: Automatic destroy for dev environments

## 📚 Additional Resources

### **GitHub Actions**
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Actions](https://github.com/aws-actions)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)

### **Security**
- [OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

### **Monitoring**
- [Kubernetes Monitoring](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [AWS CloudWatch](https://docs.aws.amazon.com/cloudwatch/)

---

This CI/CD setup provides **enterprise-grade automation** with **security best practices**, **fast deployment cycles**, and **comprehensive validation** for the Character Sheet application. 