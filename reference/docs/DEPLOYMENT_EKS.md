# EKS Deployment Guide - Character Sheet Application

This guide covers deploying the Character Sheet application to AWS using **Amazon EKS (Elastic Kubernetes Service)** with **comprehensive geo-restriction** to US, Canada, and European IPs only.

## 🏗️ Architecture Overview

### **Infrastructure Components**
```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS CLOUD (us-west-2)                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                      WAF v2                                 │ │
│  │  • Geo-restriction (US/CA/EU only)                        │ │
│  │  • Rate limiting (2000 req/5min)                          │ │
│  │  • AWS Managed Rules                                       │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │               Application Load Balancer                     │ │
│  │  • SSL termination                                         │ │
│  │  • Path-based routing                                      │ │
│  │  • Health checks                                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    EKS Cluster                              │ │
│  │  ┌─────────────────┐  ┌─────────────────┐                 │ │
│  │  │   Worker Node   │  │   Worker Node   │                 │ │
│  │  │   (t3.small)    │  │   (t3.small)    │                 │ │
│  │  │                 │  │                 │                 │ │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │                 │ │
│  │  │ │Backend Pod  │ │  │ │Backend Pod  │ │                 │ │
│  │  │ │(Go/Gin API) │ │  │ │(Go/Gin API) │ │                 │ │
│  │  │ └─────────────┘ │  │ └─────────────┘ │                 │ │
│  │  │ ┌─────────────┐ │  │                 │                 │ │
│  │  │ │PostgreSQL   │ │  │                 │                 │ │
│  │  │ │Pod          │ │  │                 │                 │ │
│  │  │ └─────────────┘ │  │                 │                 │ │
│  │  └─────────────────┘  └─────────────────┘                 │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                   VPC (10.0.0.0/16)                        │ │
│  │  ┌─────────────────┐              ┌─────────────────┐      │ │
│  │  │ Public Subnet   │              │ Public Subnet   │      │ │
│  │  │ (10.0.1.0/24)   │              │ (10.0.2.0/24)   │      │ │
│  │  │ AZ us-west-2a   │              │ AZ us-west-2b   │      │ │
│  │  └─────────────────┘              └─────────────────┘      │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### **Geo-Restriction Implementation**

**Three-Layer Security Approach:**

1. **EKS API Server Level**
   - `public_access_cidrs` in EKS cluster configuration
   - Restricts who can access the Kubernetes API

2. **ALB/Service Level** 
   - `loadBalancerSourceRanges` in Kubernetes services
   - Controls access to application endpoints

3. **WAF Level**
   - Geographic country-based filtering
   - Rate limiting and attack protection

## 🚀 Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **kubectl** installed
4. **Terraform** >= 1.0
5. **Docker** for building container images
6. **Helm** (optional, for AWS Load Balancer Controller)

## 📋 Required AWS Permissions

Your AWS user/role needs these permissions:
```bash
# EKS permissions
eks:*
# EC2 permissions for VPC and nodes
ec2:*
# IAM permissions for roles
iam:*
# WAF permissions
wafv2:*
# CloudWatch permissions
logs:*
cloudwatch:*
# Application Load Balancer permissions
elasticloadbalancing:*
```

## 🛠️ Deployment Steps

### 1. Infrastructure Deployment (Terraform)

#### **Configure Variables**
```bash
cd character-sheet-app/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
# Basic Configuration
aws_region = "us-west-2"
project_name = "character-sheet"
environment = "prod"

# Cost Optimization
enable_nat_gateway = false  # Save ~$32/month
ssh_key_name = "your-key-name"  # Optional: for node SSH access

# Database Configuration
db_password = "your-secure-db-password"
jwt_secret = "your-32-character-jwt-secret-key"

# Networking
vpc_cidr = "10.0.0.0/16"
```

#### **Deploy Infrastructure**
```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure (creates EKS cluster + WAF + networking)
terraform apply
```

**What Terraform Creates:**

1. **VPC & Networking**
   - VPC with public subnets in 2 AZs
   - Internet Gateway
   - Route tables and associations
   - Security groups with geo-restrictions

2. **EKS Cluster**
   - Managed Kubernetes control plane (v1.28)
   - Node group with t3.small instances (2-4 nodes)
   - Proper IAM roles and policies
   - CloudWatch logging enabled

3. **WAF v2 Web ACL**
   - Geographic restrictions (US/CA/EU only)
   - Rate limiting (2000 requests per 5 minutes)
   - AWS managed security rules
   - CloudWatch monitoring dashboard

4. **Security Groups**
   - EKS cluster security group
   - Node security group with restricted SSH access
   - Database security group

5. **Application Load Balancer** (created by Kubernetes ingress)
   - Internet-facing ALB
   - Health checks configured
   - WAF association

### 2. Configure kubectl

```bash
# Configure kubectl to access your EKS cluster
aws eks --region us-west-2 update-kubeconfig --name character-sheet-prod-eks

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### 3. Install AWS Load Balancer Controller

The AWS Load Balancer Controller is required for ALB ingress functionality:

```bash
# Add the EKS chart repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=character-sheet-prod-eks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 4. Deploy Application to Kubernetes

#### **Option A: Using Kustomize (Recommended)**
```bash
cd character-sheet-app/k8s

# Deploy all resources
kubectl apply -k .

# Check deployment status
kubectl get all -n character-sheet
```

#### **Option B: Deploy Individual Resources**
```bash
cd character-sheet-app/k8s

# Deploy in order
kubectl apply -f namespace.yaml
kubectl apply -f postgres-configmap.yaml
kubectl apply -f postgres-secret.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f postgres-service.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f ingress.yaml
```

## 📊 Kubernetes Resources Explained

### **Namespace** (`namespace.yaml`)
```yaml
# Creates a dedicated namespace for all app resources
# Provides logical separation and resource organization
apiVersion: v1
kind: Namespace
metadata:
  name: character-sheet
```

### **PostgreSQL Configuration** (`postgres-*.yaml`)

**ConfigMap**: Non-sensitive configuration
```yaml
# Database settings, PostgreSQL configuration
# Separates config from application code
POSTGRES_DB: "character_sheets"
POSTGRES_USER: "postgres"
```

**Secret**: Sensitive data (base64 encoded)
```yaml
# Passwords and connection strings
# In production: use AWS Secrets Manager or External Secrets Operator
POSTGRES_PASSWORD: cGFzc3dvcmQ=  # "password"
DATABASE_URL: postgresql://postgres:password@postgres-service:5432/...
```

**Deployment**: Database pods
```yaml
# Single replica PostgreSQL with persistent storage
# Health checks: liveness and readiness probes
# Resource limits: 256Mi memory, 100m CPU
```

**Service**: Network endpoint
```yaml
# ClusterIP service for internal access only
# Provides stable DNS name: postgres-service.character-sheet.svc.cluster.local
```

### **Backend API Configuration** (`backend-*.yaml`)

**Deployment**: Go application pods
```yaml
# 2 replicas for high availability
# Rolling update strategy (zero downtime)
# Health checks on /health endpoint
# Resource limits: 256Mi memory, 200m CPU
# Environment variables from secrets
```

**Service**: Load balancing
```yaml
# LoadBalancer type creates AWS NLB
# Geo-restriction via loadBalancerSourceRanges
# Maps external port 80 to container port 8080
```

**HPA**: Auto-scaling
```yaml
# Horizontal Pod Autoscaler
# Scale 2-10 pods based on CPU (70%) and memory (80%)
# Prevents resource starvation
```

### **Ingress** (`ingress.yaml`)
```yaml
# Creates AWS Application Load Balancer
# Path-based routing (/api, /health, /)
# WAF integration for geo-restriction
# SSL termination (when certificate configured)
```

## 🔒 Security Features

### **Multi-Layer Geo-Restriction**

1. **EKS API Server**
   ```yaml
   public_access_cidrs = [
     "3.0.0.0/8",    # US ranges
     "142.0.0.0/8",  # Canada ranges  
     "2.0.0.0/8",    # Europe ranges
     # ... more ranges
   ]
   ```

2. **Kubernetes Service**
   ```yaml
   loadBalancerSourceRanges:
     - "3.0.0.0/8"      # Amazon/AWS US
     - "142.0.0.0/8"    # Canadian ISPs
     - "2.0.0.0/8"      # European ISPs
   ```

3. **WAF Web ACL**
   ```yaml
   country_codes = ["US", "CA", "GB", "DE", "FR", ...] # Country-level blocking
   ```

### **Additional Security**
- **Rate Limiting**: 2000 requests per 5 minutes per IP
- **AWS Managed Rules**: Protection against common attacks
- **Security Groups**: Network-level access control
- **Non-root Containers**: Pods run as user 1000
- **Resource Limits**: Prevent resource exhaustion

## 📈 Monitoring & Observability

### **CloudWatch Integration**
```bash
# View EKS cluster logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks"

# View WAF metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name AllowedRequests \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### **Kubernetes Monitoring**
```bash
# Check pod status
kubectl get pods -n character-sheet

# View pod logs
kubectl logs -f deployment/backend-deployment -n character-sheet

# Check services and endpoints
kubectl get svc,endpoints -n character-sheet

# Monitor resource usage
kubectl top pods -n character-sheet
kubectl top nodes
```

### **Application Health**
```bash
# Health check endpoint
curl http://your-alb-dns-name/health

# Check ingress status
kubectl describe ingress character-sheet-ingress -n character-sheet
```

## 🔧 Operational Commands

### **Scaling Operations**
```bash
# Manual pod scaling
kubectl scale deployment backend-deployment --replicas=5 -n character-sheet

# Check HPA status
kubectl get hpa -n character-sheet

# Update HPA settings
kubectl patch hpa backend-hpa -n character-sheet -p '{"spec":{"maxReplicas":15}}'
```

### **Rolling Updates**
```bash
# Update backend image
kubectl set image deployment/backend-deployment backend=new-image:tag -n character-sheet

# Check rollout status
kubectl rollout status deployment/backend-deployment -n character-sheet

# Rollback if needed
kubectl rollout undo deployment/backend-deployment -n character-sheet
```

### **Database Operations**
```bash
# Connect to PostgreSQL pod
kubectl exec -it deployment/postgres-deployment -n character-sheet -- psql -U postgres -d character_sheets

# Backup database
kubectl exec deployment/postgres-deployment -n character-sheet -- pg_dump -U postgres character_sheets > backup.sql

# View database logs
kubectl logs deployment/postgres-deployment -n character-sheet
```

## 💰 Cost Optimization

### **Current Configuration Costs (Monthly)**

**Without NAT Gateway (Recommended for development):**
- EKS Cluster: $72 (control plane)
- EC2 Instances: $30 (2x t3.small)
- EBS Volumes: $5 (20GB x 2 nodes + 5GB PVC)
- ALB: $18
- WAF: $1 + request charges
- **Total: ~$126/month**

**With NAT Gateway (Production):**
- Add $32/month for NAT Gateway
- **Total: ~$158/month**

### **Free Tier Impact**
- **EC2 Free Tier**: 750 hours t3.micro (not applicable to t3.small)
- **EBS Free Tier**: 30GB GP2 storage (covers node storage)
- **ALB Free Tier**: Not applicable (ALB has no free tier)

### **Cost Reduction Strategies**
1. **Spot Instances**: Use spot instances for worker nodes (75% savings)
2. **Cluster Autoscaler**: Automatically scale nodes based on demand
3. **Smaller Instances**: Use t3.micro for development (if workload fits)
4. **Reserved Instances**: 1-year commitment for 40% savings

## 🔄 CI/CD Integration

### **GitHub Actions Workflow**
```yaml
# .github/workflows/deploy-eks.yml
name: Deploy to EKS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-west-2
    
    - name: Login to ECR
      run: aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REGISTRY
    
    - name: Build and push Docker image
      run: |
        docker build -t $ECR_REGISTRY/character-sheet-backend:$GITHUB_SHA ./backend
        docker push $ECR_REGISTRY/character-sheet-backend:$GITHUB_SHA
    
    - name: Update kubeconfig
      run: aws eks update-kubeconfig --region us-west-2 --name character-sheet-prod-eks
    
    - name: Deploy to Kubernetes
      run: |
        cd k8s
        kustomize edit set image character-sheet-backend=$ECR_REGISTRY/character-sheet-backend:$GITHUB_SHA
        kubectl apply -k .
```

## 🚨 Troubleshooting

### **Common Issues**

**1. Nodes not joining cluster**
```bash
# Check node logs
kubectl describe nodes

# Verify IAM roles
aws iam get-role --role-name character-sheet-prod-eks-node-group-role
```

**2. Pods stuck in Pending**
```bash
# Check resource availability
kubectl describe pod <pod-name> -n character-sheet
kubectl get events -n character-sheet --sort-by='.lastTimestamp'
```

**3. LoadBalancer service stuck in Pending**
```bash
# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify subnet tags (required for ALB)
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1"
```

**4. WAF blocking legitimate traffic**
```bash
# Check WAF logs
aws logs filter-log-events \
  --log-group-name /aws/wafv2/character-sheet-prod \
  --filter-pattern "{ $.action = \"BLOCK\" }"

# Temporarily disable geo-restriction for testing
aws wafv2 update-web-acl --scope REGIONAL --id <web-acl-id> --default-action Allow={}
```

### **Debugging Commands**
```bash
# Cluster info
kubectl cluster-info
kubectl get componentstatuses

# Node information
kubectl get nodes -o wide
kubectl describe node <node-name>

# Pod debugging
kubectl get pods -n character-sheet -o wide
kubectl describe pod <pod-name> -n character-sheet
kubectl logs <pod-name> -n character-sheet --previous

# Service debugging
kubectl get svc -n character-sheet
kubectl get endpoints -n character-sheet
kubectl describe ingress character-sheet-ingress -n character-sheet
```

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kustomize Documentation](https://kustomize.io/)
- [WAF Developer Guide](https://docs.aws.amazon.com/waf/latest/developerguide/)

## 🆘 Support

For issues related to:
- **AWS EKS**: AWS Support or EKS GitHub repository
- **Kubernetes**: Kubernetes community forums
- **Application-specific**: Check application logs and health endpoints

---

This deployment creates a **production-ready, geo-restricted, highly available** Character Sheet application on AWS EKS with comprehensive security and monitoring. 