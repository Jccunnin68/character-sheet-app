# AWS Secrets Manager Integration Guide

This guide explains how to configure and manage **AWS Secrets Manager** integration with the Character Sheet application using the **External Secrets Operator** for secure, zero-secrets-in-code deployment.

> **Setup Instructions**: See [MULTI_ENVIRONMENT_SETUP.md](MULTI_ENVIRONMENT_SETUP.md) for initial deployment steps.

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

## 📋 Secret Configuration

### **Required Secrets per Environment**

Each environment needs these secrets in AWS Secrets Manager:

#### **Database Secret** (`character-sheet/database`)
```json
{
  "username": "postgres",
  "password": "your-secure-database-password",
  "database": "character_sheets",
  "host": "character-sheet-ENV-db.region.rds.amazonaws.com", 
  "port": "5432"
}
```

#### **Backend Secret** (`character-sheet/backend`)
```json
{
  "jwt_secret": "your-32-character-jwt-secret-key-here",
  "api_key": "optional-api-key-for-integrations"
}
```

### **Environment-Specific Secret Naming**

Secrets are isolated per environment using consistent naming:

| Environment | Database Secret | Backend Secret |
|-------------|----------------|----------------|
| **Dev** | `character-sheet/database` | `character-sheet/backend` |
| **PreProd** | `character-sheet/database` | `character-sheet/backend` |
| **Production** | `character-sheet/database` | `character-sheet/backend` |

> **Note**: Each environment has its own AWS account, so secret names can be the same across environments while maintaining complete isolation.

## 🔧 Manual Secret Creation

### **Using AWS CLI**

#### **Create Database Secret**
```bash
# Set environment variables
ENVIRONMENT="dev"  # Change to: dev, preprod, prod
REGION="us-west-2"

# Create database secret
aws secretsmanager create-secret \
  --name "character-sheet/database" \
  --description "Database credentials for Character Sheet ${ENVIRONMENT} environment" \
  --secret-string '{
    "username": "postgres",
    "password": "your-secure-password-here",
    "database": "character_sheets",
    "host": "character-sheet-'${ENVIRONMENT}'-db.'${REGION}'.rds.amazonaws.com",
    "port": "5432"
  }' \
  --region ${REGION}
```

#### **Create Backend Secret**
```bash
# Create backend secret
aws secretsmanager create-secret \
  --name "character-sheet/backend" \
  --description "Backend application secrets for Character Sheet ${ENVIRONMENT} environment" \
  --secret-string '{
    "jwt_secret": "your-32-character-jwt-secret-key",
    "api_key": "optional-api-key-value"
  }' \
  --region ${REGION}
```

### **Using AWS Console**

1. **Navigate to Secrets Manager**
   - Go to AWS Console → Secrets Manager
   - Select your environment's AWS account
   - Click "Store a new secret"

2. **Configure Secret**
   - **Secret type**: "Other type of secret"
   - **Key/value pairs**: Add the JSON structure above
   - **Encryption key**: Use default AWS managed key
   - **Secret name**: `character-sheet/database` or `character-sheet/backend`

3. **Configure Rotation** (Optional)
   - Enable automatic rotation for database passwords
   - Set rotation schedule (e.g., every 30 days)

## 🛠️ External Secrets Operator Configuration

### **SecretStore Configuration**

The SecretStore connects to AWS Secrets Manager:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager-store
  namespace: character-sheet
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

### **ExternalSecret for Database**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-external-secret
  namespace: character-sheet
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager-store
    kind: SecretStore
  target:
    name: postgres-secret
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        POSTGRES_USER: "{{ .username | toString }}"
        POSTGRES_PASSWORD: "{{ .password | toString }}"
        POSTGRES_DB: "{{ .database | toString }}"
        POSTGRES_HOST: "{{ .host | toString }}"
        POSTGRES_PORT: "{{ .port | toString }}"
        DATABASE_URL: "postgresql://{{ .username }}:{{ .password }}@{{ .host }}:{{ .port }}/{{ .database }}"
  data:
  - secretKey: username
    remoteRef:
      key: character-sheet/database
      property: username
  - secretKey: password
    remoteRef:
      key: character-sheet/database
      property: password
  - secretKey: database
    remoteRef:
      key: character-sheet/database
      property: database
  - secretKey: host
    remoteRef:
      key: character-sheet/database
      property: host
  - secretKey: port
    remoteRef:
      key: character-sheet/database
      property: port
```

### **ExternalSecret for Backend**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: backend-external-secret
  namespace: character-sheet
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager-store
    kind: SecretStore
  target:
    name: backend-secret
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        JWT_SECRET: "{{ .jwt_secret | toString }}"
        API_KEY: "{{ .api_key | toString }}"
  data:
  - secretKey: jwt_secret
    remoteRef:
      key: character-sheet/backend
      property: jwt_secret
  - secretKey: api_key
    remoteRef:
      key: character-sheet/backend
      property: api_key
```

## 🔐 IAM Configuration

### **Service Account with IRSA**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: character-sheet
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/character-sheet-ENV-external-secrets-role"
```

### **IAM Role Policy**

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
        "arn:aws:secretsmanager:us-west-2:ACCOUNT_ID:secret:character-sheet/*"
      ]
    }
  ]
}
```

### **Trust Relationship**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/CLUSTER_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-west-2.amazonaws.com/id/CLUSTER_ID:sub": "system:serviceaccount:character-sheet:external-secrets-sa",
          "oidc.eks.us-west-2.amazonaws.com/id/CLUSTER_ID:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

## 🔄 Secret Rotation

### **Automatic Database Password Rotation**

Configure automatic rotation for database passwords:

```bash
# Enable rotation
aws secretsmanager rotate-secret \
  --secret-id character-sheet/database \
  --rotation-rules AutomaticallyAfterDays=30 \
  --rotation-lambda-arn arn:aws:lambda:us-west-2:ACCOUNT:function:SecretsManagerRDSPostgreSQLRotationSingleUser
```

### **Manual Secret Updates**

```bash
# Update database password
aws secretsmanager update-secret \
  --secret-id character-sheet/database \
  --secret-string '{
    "username": "postgres",
    "password": "new-secure-password",
    "database": "character_sheets",
    "host": "character-sheet-prod-db.us-west-2.rds.amazonaws.com",
    "port": "5432"
  }'

# Update JWT secret
aws secretsmanager update-secret \
  --secret-id character-sheet/backend \
  --secret-string '{
    "jwt_secret": "new-32-character-jwt-secret-key",
    "api_key": "new-api-key-value"
  }'
```

### **Refresh External Secrets**

After updating secrets in AWS Secrets Manager, force refresh:

```bash
# Manually trigger secret refresh
kubectl annotate externalsecret postgres-external-secret \
  force-sync=$(date +%s) -n character-sheet

kubectl annotate externalsecret backend-external-secret \
  force-sync=$(date +%s) -n character-sheet
```

## 🔍 Monitoring & Troubleshooting

### **Verify Secret Sync Status**

```bash
# Check ExternalSecret status
kubectl get externalsecrets -n character-sheet

# Detailed status
kubectl describe externalsecret postgres-external-secret -n character-sheet
kubectl describe externalsecret backend-external-secret -n character-sheet

# Check generated Kubernetes secrets
kubectl get secrets -n character-sheet
kubectl describe secret postgres-secret -n character-sheet
```

### **External Secrets Operator Logs**

```bash
# Check operator logs
kubectl logs -n external-secrets-system deployment/external-secrets -f

# Check specific controller logs
kubectl logs -n external-secrets-system deployment/external-secrets-cert-controller -f
kubectl logs -n external-secrets-system deployment/external-secrets-webhook -f
```

### **Test Secret Access**

```bash
# Test AWS Secrets Manager access from pod
kubectl run test-pod --image=amazon/aws-cli --rm -it -- /bin/bash

# Inside the pod:
aws secretsmanager get-secret-value \
  --secret-id character-sheet/database \
  --region us-west-2
```

### **Common Issues**

#### **Secret Not Found**
```bash
# Verify secret exists in correct region/account
aws secretsmanager describe-secret --secret-id character-sheet/database

# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/external-secrets-role \
  --action-names secretsmanager:GetSecretValue \
  --resource-arns arn:aws:secretsmanager:us-west-2:ACCOUNT:secret:character-sheet/database
```

#### **IRSA Not Working**
```bash
# Check service account annotations
kubectl describe serviceaccount external-secrets-sa -n character-sheet

# Verify OIDC provider
aws iam list-open-id-connect-providers

# Check trust relationship
aws iam get-role --role-name character-sheet-external-secrets-role
```

#### **ExternalSecret Failing**
```bash
# Check events
kubectl get events -n character-sheet --field-selector involvedObject.name=postgres-external-secret

# Check operator status
kubectl get externalsecrets postgres-external-secret -o yaml
```

## 📚 Best Practices

### **Security**
1. **Least Privilege**: Grant minimal required permissions to IAM roles
2. **Secret Scoping**: Use environment-specific secret paths
3. **Rotation**: Enable automatic rotation for database passwords
4. **Monitoring**: Set up CloudTrail for secret access auditing

### **Operations**
1. **Refresh Intervals**: Set appropriate refresh intervals (15s for dev, 60s for prod)
2. **Error Handling**: Monitor ExternalSecret status and set up alerts
3. **Backup**: Consider backing up critical secrets to secure storage
4. **Documentation**: Document secret schemas and rotation procedures

### **Development**
1. **Local Development**: Use different secrets for local development
2. **Testing**: Test secret rotation procedures in non-production environments
3. **Validation**: Validate secret formats before storing in Secrets Manager

---

**Questions about secrets management?** See [MULTI_ENVIRONMENT_SETUP.md](MULTI_ENVIRONMENT_SETUP.md) for initial setup or [README_EKS.md](README_EKS.md) for architecture details. 