# AWS Secrets Manager Integration Guide

This guide explains how the Character Sheet application has been refactored to use **AWS Secrets Manager** instead of storing secrets in the codebase. All sensitive data is now securely managed through AWS Secrets Manager and accessed via the **External Secrets Operator**.

## 🔒 Security Benefits

### **Before (Hardcoded Secrets)**
- ❌ Secrets stored as base64 in Kubernetes manifests
- ❌ Secrets visible in Git repository
- ❌ No rotation capabilities
- ❌ No audit trail for secret access
- ❌ Secrets shared across environments

### **After (AWS Secrets Manager)**
- ✅ Secrets stored securely in AWS Secrets Manager
- ✅ No secrets in codebase
- ✅ Automatic rotation support
- ✅ Complete audit trail via CloudTrail
- ✅ Environment-specific secrets
- ✅ Fine-grained IAM permissions

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Secrets Manager                        │
│  ┌─────────────────────┐  ┌─────────────────────┐              │
│  │ character-sheet/    │  │ character-sheet/    │              │
│  │ database            │  │ backend             │              │
│  │ ├── username        │  │ ├── jwt_secret      │              │
│  │ ├── password        │  │ └── api_key         │              │
│  │ ├── database        │  │                     │              │
│  │ ├── host            │  │                     │              │
│  │ └── port            │  │                     │              │
│  └─────────────────────┘  └─────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ IRSA (IAM Roles for Service Accounts)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EKS Cluster                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │            External Secrets Operator                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │ │
│  │  │SecretStore  │    │ExternalSecret│    │ExternalSecret│    │ │
│  │  │(AWS SM)     │    │(Database)    │    │(Backend)     │    │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘    │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │               Kubernetes Secrets                            │ │
│  │  ┌─────────────┐              ┌─────────────┐              │ │
│  │  │postgres-    │              │backend-     │              │ │
│  │  │secret       │              │secret       │              │ │
│  │  └─────────────┘              └─────────────┘              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 Application Pods                            │ │
│  │  ┌─────────────┐              ┌─────────────┐              │ │
│  │  │PostgreSQL   │              │Backend API  │              │ │
│  │  │Pod          │              │Pod          │              │ │
│  │  └─────────────┘              └─────────────┘              │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Components

### **1. AWS Secrets Manager Secrets**

**Database Secret** (`character-sheet/database`):
```json
{
  "username": "postgres",
  "password": "your-secure-password",
  "database": "character_sheets",
  "host": "rds-endpoint.amazonaws.com", 
  "port": "5432"
}
```

**Backend Secret** (`character-sheet/backend`):
```json
{
  "jwt_secret": "your-32-character-jwt-secret-key",
  "api_key": "optional-api-key-for-integrations"
}
```

### **2. External Secrets Operator**

**SecretStore**: Connects to AWS Secrets Manager
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

**ExternalSecret**: Pulls specific secrets and creates Kubernetes Secrets
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-external-secret
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager-store
  target:
    name: postgres-secret
    template:
      data:
        POSTGRES_PASSWORD: "{{ .postgres_password | toString }}"
        DATABASE_URL: "postgresql://{{ .postgres_user }}:{{ .postgres_password }}@postgres-service:5432/{{ .postgres_db }}"
```

### **3. IAM Roles for Service Accounts (IRSA)**

**External Secrets Service Account**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT:role/character-sheet-external-secrets-role"
```

**IAM Role with Secrets Manager Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-west-2:ACCOUNT:secret:character-sheet/*"
      ]
    }
  ]
}
```

## 🚀 Deployment Process

### **1. Automated Deployment**
```bash
# Single command deployment (includes External Secrets setup)
./deploy-eks.sh
```

### **2. Manual Step-by-Step**

**Step 1: Deploy Infrastructure**
```bash
cd terraform
terraform apply
```

**Step 2: Install External Secrets Operator**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  -f k8s/external-secrets-operator-values.yaml
```

**Step 3: Deploy Application**
```bash
cd k8s
kubectl apply -k .
```

## 🔧 Managing Secrets

### **Adding New Secrets**

**1. Add to AWS Secrets Manager**
```bash
aws secretsmanager create-secret \
  --name "character-sheet/new-service" \
  --description "Secrets for new service" \
  --secret-string '{"api_key":"your-secret-value"}'
```

**2. Update IAM Policy**
```hcl
# In terraform/secrets-manager.tf
resource "aws_iam_policy" "external_secrets" {
  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.database.arn,
          aws_secretsmanager_secret.backend.arn,
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:character-sheet/new-service*"
        ]
      }
    ]
  })
}
```

**3. Create ExternalSecret**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: new-service-external-secret
  namespace: character-sheet
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager-store
  target:
    name: new-service-secret
  data:
  - secretKey: api_key
    remoteRef:
      key: character-sheet/new-service
      property: api_key
```

### **Rotating Secrets**

**1. Update Secret in AWS Secrets Manager**
```bash
aws secretsmanager update-secret \
  --secret-id "character-sheet/database" \
  --secret-string '{"username":"postgres","password":"new-password","database":"character_sheets"}'
```

**2. Force Refresh (Optional)**
```bash
# External Secrets will automatically refresh within 15 seconds
# Or force immediate refresh:
kubectl annotate externalsecret postgres-external-secret \
  -n character-sheet \
  force-sync=$(date +%s) --overwrite
```

**3. Restart Pods (If Needed)**
```bash
kubectl rollout restart deployment/postgres-deployment -n character-sheet
kubectl rollout restart deployment/backend-deployment -n character-sheet
```

## 🛠️ Troubleshooting

### **Common Issues**

**1. ExternalSecret Not Syncing**
```bash
# Check ExternalSecret status
kubectl describe externalsecret postgres-external-secret -n character-sheet

# Check External Secrets Operator logs
kubectl logs -n external-secrets-system deployment/external-secrets
```

**2. IAM Permission Issues**
```bash
# Check service account annotations
kubectl describe serviceaccount external-secrets-sa -n character-sheet

# Verify IAM role trust policy
aws iam get-role --role-name character-sheet-prod-external-secrets-role
```

**3. Secret Not Found in AWS**
```bash
# List secrets
aws secretsmanager list-secrets --filter Key=name,Values=character-sheet

# Get secret value
aws secretsmanager get-secret-value --secret-id character-sheet/database
```

### **Debugging Commands**

**Check External Secrets Status**
```bash
# List all external secrets
kubectl get externalsecrets -n character-sheet

# Check secret store
kubectl get secretstore -n character-sheet

# View generated secrets
kubectl get secrets -n character-sheet
kubectl describe secret postgres-secret -n character-sheet
```

**External Secrets Operator Logs**
```bash
# Controller logs
kubectl logs -n external-secrets-system deployment/external-secrets

# Webhook logs  
kubectl logs -n external-secrets-system deployment/external-secrets-webhook
```

## 📊 Monitoring and Alerts

### **CloudWatch Metrics**
- Secret retrieval success/failure rates
- External Secrets sync frequency
- IAM role usage patterns

### **Recommended Alerts**
```bash
# External Secret sync failures
kubectl get externalsecrets -n character-sheet -o json | \
jq '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="False"))'

# Missing secrets
kubectl get secrets -n character-sheet --field-selector type=Opaque
```

## 💰 Cost Implications

### **AWS Secrets Manager Costs**
- **Secrets**: $0.40 per secret per month
- **API Calls**: $0.05 per 10,000 requests
- **Monthly Cost**: ~$1-2 for typical usage

### **External Secrets Operator**
- **EKS Resources**: Minimal CPU/memory usage
- **No Additional AWS Charges**: Uses existing EKS nodes

## 🔐 Security Best Practices

### **1. Secret Naming Convention**
```
application-name/component/secret-type
Example: character-sheet/database/credentials
```

### **2. IAM Policy Least Privilege**
- Only grant access to specific secret ARNs
- Use condition statements for additional restrictions
- Regular IAM access reviews

### **3. Secret Rotation**
- Enable automatic rotation for database credentials
- Implement secret versioning strategy
- Monitor secret age and usage

### **4. Audit and Monitoring**
- Enable CloudTrail for Secrets Manager API calls
- Set up alerts for unauthorized access attempts
- Regular security audits of secret access patterns

## 📚 Additional Resources

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [AWS Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/)
- [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/)

---

This setup provides **enterprise-grade secret management** with **zero secrets in the codebase**, **automatic rotation capabilities**, and **comprehensive audit trails**. 