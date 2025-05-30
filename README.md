# Character Sheet Web Application

A **production-ready, multi-environment** character sheet application with **separated infrastructure and application workflows**, **complete account isolation**, and **enterprise security**. Built with Go backend, React frontend, PostgreSQL database, and deployed on **Amazon EKS across multiple AWS accounts**.

## 🏗️ Architecture Overview

### **Multi-Account Structure**
- **Shared Account**: ECR repository and cross-account networking
- **Dev Account**: Development environment (cost-optimized)
- **PreProd Account**: Pre-production testing environment  
- **Production Account**: Production environment (full enterprise features)

### **Branch-Based Deployment Flow**
```
main branch → Dev Environment (automatic)
release branch → PreProd Environment (automatic) 
Manual workflow → Production Environment (controlled)
```

## 🚀 Quick Start

### **Prerequisites**
- 4 AWS accounts (Shared, Dev, PreProd, Production) 
- GitHub repository with secrets configured
- AWS CLI, Terraform, kubectl, Docker, Helm

### **1. Initial Setup**
```bash
git clone <repository-url>
cd character-sheet-app

# Create release branch for preprod deployments
git checkout -b release
git push origin release
```

### **2. Deploy Infrastructure** 
```bash
# Deploy shared resources first
Actions → Deploy Networking → action: apply

# Deploy environment infrastructure  
Actions → Deploy Infrastructure → environment: dev, action: apply
Actions → Deploy Infrastructure → environment: preprod, action: apply
Actions → Deploy Infrastructure → environment: prod, action: apply
```

### **3. Deploy Applications**
```bash
# Development workflow
git checkout main
git add .
git commit -m "feat: new feature"
git push origin main  # → Auto-deploys to Dev

# PreProd workflow  
git checkout release
git merge main
git push origin release  # → Auto-deploys to PreProd

# Production workflow (manual only)
Actions → Deploy Applications → target_environment: prod
```

### **4. Local Development**
```bash
docker-compose up

# Services available at:
# Frontend: http://localhost:3000
# Backend:  http://localhost:8080  
# Database: localhost:5432
```

## 🔄 Workflows Overview

| Workflow | Trigger | Target | Duration |
|----------|---------|--------|----------|
| **Deploy Infrastructure** | Manual only | All environments | 15-25 min |
| **Deploy Applications** | `main` branch | Dev Environment | 10-15 min |
| **Deploy Applications** | `release` branch | PreProd Environment | 10-15 min |
| **Deploy Applications** | Manual | Production Environment | 15-20 min |

## 🛡️ Key Features

- ✅ **Multi-Account Isolation**: Complete environment separation
- ✅ **Branch-Based CI/CD**: Controlled promotion flow  
- ✅ **Zero Secrets in Code**: AWS Secrets Manager integration
- ✅ **Infrastructure as Code**: Terraform for all resources
- ✅ **Security Controls**: Geo-restriction, WAF, OIDC authentication
- ✅ **Cost Optimization**: Environment-specific resource sizing

## 💰 Cost Estimates

| Environment | Monthly Cost | Purpose |
|-------------|--------------|---------|
| **Dev** | $35-50 | Development and testing |
| **PreProd** | $50-70 | Release candidate validation |
| **Production** | $120-150 | Production workloads |
| **Shared** | $5-10 | ECR and shared resources |

**Total: $210-280/month** for complete enterprise setup

## 📚 Documentation

### **Setup & Configuration**
- **[MULTI_ENVIRONMENT_SETUP.md](MULTI_ENVIRONMENT_SETUP.md)** - Complete setup guide with AWS account configuration
- **[SECRETS_MANAGER_SETUP.md](SECRETS_MANAGER_SETUP.md)** - AWS Secrets Manager integration details

### **Workflows & Operations**  
- **[WORKFLOW_SEPARATION.md](WORKFLOW_SEPARATION.md)** - Branch-based workflow guide and best practices

### **Architecture & Reference**
- **[README_EKS.md](README_EKS.md)** - Detailed architecture overview and technical specifications
- **[reference/](reference/)** - ECS implementation and legacy configurations

### **Component Documentation**
- [Frontend Setup](./frontend/README.md) - React development guide
- [Backend Setup](./backend/README.md) - Go API development guide  
- [Database Setup](./database/README.md) - PostgreSQL schema and migrations

## 🔄 Migration Options

### **Enterprise Users (Current Setup)**
- Multi-environment EKS with complete account isolation
- Advanced CI/CD with branch-based promotion
- Full enterprise security and compliance features

### **Cost-Conscious Users**  
- **ECS Alternative**: See `reference/terraform/` for AWS Free Tier optimization (~$35-50/month)
- Single-environment deployment option
- Simpler architecture without Kubernetes complexity

---

**Ready to deploy?** Start with **[MULTI_ENVIRONMENT_SETUP.md](MULTI_ENVIRONMENT_SETUP.md)** for complete setup instructions, then review **[WORKFLOW_SEPARATION.md](WORKFLOW_SEPARATION.md)** for workflow details. 