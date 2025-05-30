# Character Sheet Application - EKS Deployment

## 🎯 Overview

This project has been **refactored to use Amazon EKS (Elastic Kubernetes Service)** instead of ECS, providing a cloud-native, highly scalable, and geo-restricted character sheet application. The deployment includes **comprehensive firewall rules** that restrict access to **US, Canada, and European IPs only**.

**🔒 NEW: AWS Secrets Manager Integration** - All secrets are now securely managed through AWS Secrets Manager with External Secrets Operator, eliminating hardcoded secrets from the codebase.

## 🏗️ Architecture Summary

### **From ECS to EKS Migration**
- ✅ **ECS Tasks** → **Kubernetes Pods**
- ✅ **ECS Services** → **Kubernetes Deployments + Services**
- ✅ **Application Load Balancer** → **ALB Ingress Controller**
- ✅ **Task Definitions** → **Kubernetes Manifests**
- ✅ **Auto Scaling Groups** → **Horizontal Pod Autoscaler**
- ✅ **Hardcoded Secrets** → **AWS Secrets Manager + External Secrets Operator**

### **Enhanced Security Features**
- 🔒 **Three-Layer Geo-Restriction** (EKS API + Service + WAF)
- 🛡️ **WAF v2 with Country-Level Blocking**
- 🌍 **IP Range Restrictions** for US/Canada/Europe
- ⚡ **Rate Limiting** (2000 requests per 5 minutes)
- 🔐 **AWS Managed Security Rules**
- 🔑 **AWS Secrets Manager Integration** (Zero secrets in codebase)

## 📁 Project Structure

```
character-sheet-app/
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                     # VPC, networking, basic resources
│   ├── eks.tf                      # ⭐ EKS cluster configuration
│   ├── waf.tf                      # ⭐ WAF geo-restriction rules
│   ├── secrets-manager.tf          # ⭐ AWS Secrets Manager & IAM roles
│   ├── variables.tf                # Configuration variables
│   └── outputs.tf                  # Infrastructure outputs
├── k8s/                            # ⭐ Kubernetes manifests
│   ├── namespace.yaml              # Application namespace
│   ├── postgres-configmap.yaml     # Database configuration
│   ├── external-secrets.yaml       # ⭐ External Secrets Operator config
│   ├── postgres-deployment.yaml    # PostgreSQL deployment + PVC
│   ├── postgres-service.yaml       # Database service
│   ├── backend-deployment.yaml     # Go API deployment + HPA
│   ├── backend-service.yaml        # API service with geo-restriction
│   ├── ingress.yaml                # ALB ingress with WAF
│   ├── external-secrets-operator-values.yaml  # ⭐ Helm values for External Secrets
│   └── kustomization.yaml          # Kustomize configuration
├── deploy-eks.sh                   # ⭐ Automated deployment script
├── DEPLOYMENT_EKS.md               # ⭐ Comprehensive deployment guide
├── SECRETS_MANAGER_SETUP.md        # ⭐ AWS Secrets Manager integration guide
└── README_EKS.md                   # This file
```

## 🌐 Geo-Restriction Implementation

### **Three-Layer Security Approach**

#### **1. EKS API Server Level** (`terraform/eks.tf`)
```hcl
public_access_cidrs = [
  "3.0.0.0/8",      # US IP ranges
  "142.0.0.0/8",    # Canada IP ranges
  "2.0.0.0/8",      # Europe IP ranges
  # ... comprehensive list of allowed IP ranges
]
```

#### **2. Kubernetes Service Level** (`k8s/backend-service.yaml`)
```yaml
loadBalancerSourceRanges:
  - "3.0.0.0/8"     # Amazon/AWS US
  - "142.0.0.0/8"   # Canadian ISPs
  - "2.0.0.0/8"     # European ISPs
  # ... detailed geo IP ranges
```

#### **3. AWS WAF Level** (`terraform/waf.tf`)
```hcl
country_codes = [
  "US", "CA",                    # North America
  "GB", "DE", "FR", "IT", "ES",  # Western Europe
  "SE", "NO", "DK", "FI",        # Nordic countries
  # ... complete list of allowed countries
]
```

## 🚀 Quick Start

### **1. Prerequisites**
```bash
# Required tools
aws --version     # AWS CLI
terraform --version   # Terraform >= 1.0
kubectl version   # kubectl
docker --version  # Docker
helm version      # Helm (optional)
```

### **2. Configure Infrastructure**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
```

### **3. Deploy Everything**
```bash
# Automated deployment (recommended)
./deploy-eks.sh

# Or manual step-by-step deployment
# See DEPLOYMENT_EKS.md for detailed instructions
```

### **4. Access Application**
```bash
# Get application URL
kubectl get ingress -n character-sheet

# Check application health
curl http://your-alb-dns/health
```

## 📊 Kubernetes Resources Explained

### **Database Layer**
- **ConfigMap**: Non-sensitive PostgreSQL configuration
- **Secret**: Database passwords and connection strings (base64 encoded)
- **Deployment**: Single replica PostgreSQL with persistent storage
- **PVC**: 5GB persistent volume for database data
- **Service**: ClusterIP service for internal database access

### **Application Layer**
- **Deployment**: 2-replica Go backend with rolling updates
- **HPA**: Auto-scaling 2-10 pods based on CPU (70%) and memory (80%)
- **Service**: LoadBalancer with geo-restriction creating AWS NLB
- **Secret**: JWT tokens and application secrets

### **Network Layer**
- **Ingress**: ALB with path-based routing and WAF integration
- **Service**: Internal ClusterIP for ingress communication
- **WAF**: Geographic and rate limiting protection

## 🔧 Key Kubernetes Features

### **High Availability**
```yaml
# Multiple replicas with anti-affinity
replicas: 2
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
    maxSurge: 1
```

### **Health Checks**
```yaml
# Comprehensive health monitoring
livenessProbe:    # Restart if unhealthy
readinessProbe:   # Don't send traffic if not ready
startupProbe:     # Allow slow startup times
```

### **Resource Management**
```yaml
# Prevent resource starvation
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### **Auto-Scaling**
```yaml
# Horizontal Pod Autoscaler
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70%
```

## 🛡️ Security Features

### **Network Security**
- Security groups with geo-restricted SSH access
- Private internal communication between services
- WAF protection against common attacks

### **Container Security**
- Non-root containers (runAsUser: 1000)
- Resource limits to prevent DoS
- Secrets management for sensitive data

### **Access Control**
- IAM roles with least privilege
- Service accounts for pod authentication
- Network policies for traffic control

## 📈 Monitoring & Observability

### **CloudWatch Integration**
- EKS cluster logs automatically forwarded
- WAF metrics and dashboard
- Custom application metrics

### **Kubernetes Native**
```bash
# Resource monitoring
kubectl top pods -n character-sheet
kubectl top nodes

# Log aggregation
kubectl logs -f deployment/backend-deployment -n character-sheet

# Health checks
kubectl get all -n character-sheet
```

## 💰 Cost Analysis

### **Monthly Cost Estimate**
| Component | Cost (USD) | Notes |
|-----------|------------|-------|
| EKS Control Plane | $72 | Managed Kubernetes API |
| EC2 Instances (2x t3.small) | $30 | Worker nodes |
| EBS Volumes | $5 | Node storage + PVC |
| Application Load Balancer | $18 | Internet-facing ALB |
| WAF v2 | $1-5 | Base + request charges |
| **Total (no NAT)** | **~$126** | Cost-optimized |
| **Total (with NAT)** | **~$158** | Production setup |

### **Cost Optimization**
- 💰 **No NAT Gateway**: Saves $32/month (use public subnets)
- 🎯 **Spot Instances**: Up to 75% savings on worker nodes
- 📊 **Auto-scaling**: Scale to zero during low usage
- 🔄 **Reserved Instances**: 40% savings with 1-year commitment

## 🔄 CI/CD Integration

### **Docker Image Management**
```bash
# Build and push to ECR
docker build -t character-sheet-backend .
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REGISTRY
docker push $ECR_REGISTRY/character-sheet-backend:latest
```

### **Kubernetes Deployment**
```bash
# Update deployment with new image
kubectl set image deployment/backend-deployment backend=$ECR_REGISTRY/character-sheet-backend:$NEW_TAG -n character-sheet

# Monitor rollout
kubectl rollout status deployment/backend-deployment -n character-sheet
```

## 🚨 Troubleshooting

### **Common Issues**
1. **Pods Pending**: Check node resources and PVC availability
2. **LoadBalancer Pending**: Verify AWS Load Balancer Controller installation
3. **WAF Blocking**: Check CloudWatch logs for blocked requests
4. **Health Check Fails**: Verify application startup and readiness

### **Debugging Commands**
```bash
# Cluster diagnostics
kubectl cluster-info
kubectl get events -n character-sheet --sort-by='.lastTimestamp'

# Pod debugging
kubectl describe pod <pod-name> -n character-sheet
kubectl logs <pod-name> -n character-sheet --previous

# Network debugging
kubectl get svc,endpoints -n character-sheet
kubectl describe ingress character-sheet-ingress -n character-sheet
```

## 📚 Documentation

- **[DEPLOYMENT_EKS.md](DEPLOYMENT_EKS.md)**: Complete deployment guide
- **[Terraform Documentation](terraform/)**: Infrastructure details
- **[Kubernetes Manifests](k8s/)**: Application configuration
- **[Original ECS Documentation](DEPLOYMENT.md)**: Legacy deployment info

## 🎯 Migration Benefits

### **ECS → EKS Advantages**
- ✅ **Vendor Agnostic**: Standard Kubernetes APIs
- ✅ **Rich Ecosystem**: Helm charts, operators, tools
- ✅ **Advanced Scheduling**: Node affinity, taints, tolerations
- ✅ **Better Networking**: Network policies, service mesh support
- ✅ **Local Development**: Run same configs locally with kind/minikube

### **Enhanced Security**
- ✅ **Multi-Layer Geo-Restriction**: EKS + Service + WAF levels
- ✅ **Fine-grained WAF Rules**: Country-specific blocking
- ✅ **Advanced Rate Limiting**: Per-IP protection
- ✅ **Security Monitoring**: Detailed CloudWatch dashboards

## 🚀 Future Enhancements

### **Planned Improvements**
- 🔐 **External Secrets Operator**: AWS Secrets Manager integration
- 📊 **Prometheus/Grafana**: Advanced monitoring stack
- 🌐 **Service Mesh**: Istio for traffic management
- 🔄 **GitOps**: ArgoCD for declarative deployments
- 🧪 **Blue/Green Deployments**: Zero-downtime releases

---

## 🏁 Conclusion

This EKS deployment provides a **production-ready, geo-restricted, highly available** Character Sheet application with:

- 🌍 **Multi-layer geo-restriction** for US/Canada/Europe only
- 🔒 **Enterprise-grade security** with WAF and network controls
- 📈 **Auto-scaling** based on demand
- 🛡️ **High availability** with multi-AZ deployment
- 💰 **Cost optimization** with configurable NAT gateway
- 🔧 **Operational excellence** with comprehensive monitoring

The migration from ECS to EKS provides greater flexibility, industry-standard APIs, and enhanced security capabilities while maintaining the same application functionality. 