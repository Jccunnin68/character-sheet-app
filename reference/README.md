# Reference Implementations

This directory contains **legacy implementations and documentation** for reference purposes. These files are **NOT used by the current multi-environment setup** but are preserved for comparison, learning, and potential alternative implementations.

## 📁 Directory Structure

### `terraform/` - Legacy Terraform Configurations

**ECS Implementation** (Cost-optimized for AWS Free Tier):
- `ecs.tf` - Complete ECS on EC2 implementation
- `alb.tf` - Application Load Balancer for ECS
- `s3-cloudfront.tf` - Frontend deployment via S3 + CloudFront
- `user_data.sh` - EC2 instance initialization for ECS
- `terraform.tfvars.example` - Example single-environment configuration

**Key Features of ECS Implementation:**
- ✅ AWS Free Tier optimized (EC2 instead of Fargate)
- ✅ Auto Scaling Groups with single instance
- ✅ Dynamic port mapping with ALB integration
- ✅ SSH access for debugging
- ✅ CloudWatch logging with minimal retention
- ✅ No EKS control plane costs ($75/month savings)

### `workflows/` - Legacy GitHub Actions

**Single-Environment Workflows:**
- `deploy.yml` - Original ECS deployment workflow
- `deploy-infrastructure.yml` - Single-environment EKS deployment
- `deploy-app-update.yml` - Application-only updates for single environment

**Replaced by Multi-Environment Workflows:**
- `deploy-dev-preprod.yml` - Automated dev/preprod deployment
- `deploy-production.yml` - Production deployment (manual)
- `deploy-networking.yml` - Shared infrastructure deployment
- `pr-validation.yml` - Enhanced validation for all environments

### `docs/` - Legacy Documentation

**Outdated Guides:**
- `DEPLOYMENT.md` - ECS deployment guide (Free Tier focused)
- `DEPLOYMENT_EKS.md` - Single-environment EKS deployment guide
- `GITHUB_ACTIONS_SETUP.md` - Single-environment CI/CD setup

**Current Documentation:**
- `MULTI_ENVIRONMENT_SETUP.md` - Complete multi-account setup guide
- `README_EKS.md` - Multi-environment EKS architecture overview
- `SECRETS_MANAGER_SETUP.md` - AWS Secrets Manager integration

### `deploy-eks.sh` - Legacy Deployment Script

Manual deployment script replaced by GitHub Actions workflows.

## 🔄 Migration Path

### **From Single Environment to Multi-Environment**

If you want to migrate from the reference implementation to the current setup:

1. **Review Current Setup**: Read `MULTI_ENVIRONMENT_SETUP.md`
2. **Account Structure**: Set up 4 AWS accounts (Shared, Dev, PreProd, Prod)
3. **Infrastructure**: Use multi-environment Terraform configs in `terraform/environments/`
4. **CI/CD**: Configure GitHub secrets for multi-account access
5. **Deployment**: Use new GitHub Actions workflows

### **From Multi-Environment to ECS (Cost Reduction)**

If you want to use ECS instead of EKS for cost savings:

1. **Copy ECS Files**: 
   ```bash
   cp reference/terraform/ecs.tf terraform/
   cp reference/terraform/alb.tf terraform/
   cp reference/terraform/s3-cloudfront.tf terraform/
   ```

2. **Update Variables**: Modify `terraform/variables.tf` for ECS-specific configs

3. **Modify Workflows**: Adapt GitHub Actions for ECS deployment patterns

4. **Cost Savings**: ~$75/month by removing EKS control plane costs

## 💰 Cost Comparison

| Implementation | Monthly Cost | Control Plane | Complexity | Use Case |
|----------------|--------------|---------------|------------|----------|
| **ECS (Reference)** | $35-50 | None ($0) | Low | Free Tier, Small apps |
| **EKS (Current)** | $210-280 | $75/environment | High | Enterprise, Scale |

## 🧭 When to Use Reference Implementations

### **Use ECS Reference When:**
- ✅ Cost is primary concern
- ✅ Simple application requirements
- ✅ AWS Free Tier constraints
- ✅ Limited Kubernetes knowledge
- ✅ Single environment deployment

### **Use EKS Current Setup When:**
- ✅ Enterprise-grade requirements
- ✅ Multiple environments needed
- ✅ Advanced CI/CD automation
- ✅ Team collaboration
- ✅ Kubernetes ecosystem benefits
- ✅ Compliance and audit requirements

## 📚 Additional Resources

### **Learning References**
- **ECS vs EKS**: Compare container orchestration options
- **Cost Optimization**: AWS Free Tier utilization strategies
- **Migration Patterns**: Moving between different AWS services

### **Documentation Links**
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Note**: These reference implementations are maintained for **educational purposes** and **cost-optimization alternatives**. The current multi-environment setup provides **enterprise-grade capabilities** with **proper environment isolation** and **comprehensive CI/CD automation**. 