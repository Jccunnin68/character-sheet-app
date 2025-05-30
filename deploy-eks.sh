#!/bin/bash

# Character Sheet EKS Deployment Script
# This script automates the deployment of the Character Sheet application to AWS EKS
# with comprehensive geo-restriction and security features

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME=${PROJECT_NAME:-"character-sheet"}
ENVIRONMENT=${ENVIRONMENT:-"prod"}
AWS_REGION=${AWS_REGION:-"us-west-2"}
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-eks"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_commands=()
    
    if ! command_exists aws; then
        missing_commands+=("aws-cli")
    fi
    
    if ! command_exists terraform; then
        missing_commands+=("terraform")
    fi
    
    if ! command_exists kubectl; then
        missing_commands+=("kubectl")
    fi
    
    if ! command_exists docker; then
        missing_commands+=("docker")
    fi
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_commands[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check AWS authentication
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI not configured or credentials invalid"
        print_error "Please run 'aws configure' to set up your credentials"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Check if terraform.tfvars exists
    if [ ! -f terraform.tfvars ]; then
        print_error "terraform.tfvars file not found"
        print_error "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
        exit 1
    fi
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Save cluster name for later use
    echo "export CLUSTER_NAME=${CLUSTER_NAME}" > ../cluster_info.sh
    
    cd ..
    print_success "Infrastructure deployed successfully"
}

# Configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl for EKS cluster..."
    
    aws eks --region ${AWS_REGION} update-kubeconfig --name ${CLUSTER_NAME}
    
    # Test cluster connectivity
    if kubectl get nodes >/dev/null 2>&1; then
        print_success "kubectl configured successfully"
        kubectl get nodes
    else
        print_error "Failed to connect to EKS cluster"
        exit 1
    fi
}

# Install AWS Load Balancer Controller
install_alb_controller() {
    print_status "Installing AWS Load Balancer Controller..."
    
    # Check if Helm is available
    if command_exists helm; then
        # Add EKS chart repository
        helm repo add eks https://aws.github.io/eks-charts
        helm repo update
        
        # Install CRDs
        kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
        
        # Get IAM role ARN from Terraform output
        ALB_ROLE_ARN=$(cd terraform && terraform output -raw aws_load_balancer_controller_role_arn)
        
        # Create service account with IAM role annotation
        kubectl create serviceaccount aws-load-balancer-controller -n kube-system --dry-run=client -o yaml | \
        kubectl annotate --local -f - eks.amazonaws.com/role-arn=${ALB_ROLE_ARN} --dry-run=client -o yaml | \
        kubectl apply -f -
        
        # Install controller
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=${CLUSTER_NAME} \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller
        
        print_success "AWS Load Balancer Controller installed"
    else
        print_warning "Helm not found. Installing AWS Load Balancer Controller manually..."
        print_warning "Please install the AWS Load Balancer Controller manually"
    fi
}

# Install External Secrets Operator
install_external_secrets() {
    print_status "Installing External Secrets Operator..."
    
    if command_exists helm; then
        # Add External Secrets chart repository
        helm repo add external-secrets https://charts.external-secrets.io
        helm repo update
        
        # Install External Secrets Operator
        helm install external-secrets external-secrets/external-secrets \
            -n external-secrets-system \
            --create-namespace \
            -f k8s/external-secrets-operator-values.yaml
        
        # Wait for External Secrets Operator to be ready
        kubectl wait --for=condition=available --timeout=300s deployment/external-secrets -n external-secrets-system
        kubectl wait --for=condition=available --timeout=300s deployment/external-secrets-webhook -n external-secrets-system
        
        print_success "External Secrets Operator installed"
        
        # Update service account annotation with IAM role
        print_status "Configuring External Secrets service account..."
        
        # Get IAM role ARN from Terraform output
        EXTERNAL_SECRETS_ROLE_ARN=$(cd terraform && terraform output -raw external_secrets_role_arn)
        
        # Update the service account in the application namespace
        kubectl annotate serviceaccount external-secrets-sa \
            -n character-sheet \
            eks.amazonaws.com/role-arn=${EXTERNAL_SECRETS_ROLE_ARN} \
            --overwrite
        
        print_success "External Secrets service account configured"
    else
        print_error "Helm is required for External Secrets Operator installation"
        exit 1
    fi
}

# Deploy application to Kubernetes
deploy_application() {
    print_status "Deploying application to Kubernetes..."
    
    cd k8s
    
    # Check if kustomization.yaml exists
    if [ ! -f kustomization.yaml ]; then
        print_error "kustomization.yaml not found in k8s directory"
        exit 1
    fi
    
    # Process external secrets template with actual values
    print_status "Processing external secrets configuration..."
    
    # Get values from Terraform outputs
    AWS_REGION_VALUE=$(cd ../terraform && terraform output -raw aws_region 2>/dev/null || echo "${AWS_REGION}")
    EXTERNAL_SECRETS_ROLE_ARN=$(cd ../terraform && terraform output -raw external_secrets_role_arn)
    
    # Create processed external secrets file
    sed -e "s/AWS_REGION_PLACEHOLDER/${AWS_REGION_VALUE}/g" \
        -e "s|IAM_ROLE_ARN_PLACEHOLDER|${EXTERNAL_SECRETS_ROLE_ARN}|g" \
        external-secrets.yaml > external-secrets-processed.yaml
    
    # Backup original and use processed version
    mv external-secrets.yaml external-secrets-original.yaml
    mv external-secrets-processed.yaml external-secrets.yaml
    
    # Apply Kubernetes manifests
    kubectl apply -k .
    
    # Wait for external secrets to be ready
    print_status "Waiting for External Secrets to process..."
    kubectl wait --for=condition=Ready externalsecret/postgres-external-secret -n character-sheet --timeout=120s
    kubectl wait --for=condition=Ready externalsecret/backend-external-secret -n character-sheet --timeout=120s
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    kubectl rollout status deployment/postgres-deployment -n character-sheet --timeout=300s
    kubectl rollout status deployment/backend-deployment -n character-sheet --timeout=300s
    
    # Restore original file
    mv external-secrets-original.yaml external-secrets.yaml
    
    cd ..
    print_success "Application deployed successfully"
}

# Get deployment information
get_deployment_info() {
    print_status "Getting deployment information..."
    
    echo ""
    echo "=== Cluster Information ==="
    kubectl cluster-info
    
    echo ""
    echo "=== Nodes ==="
    kubectl get nodes -o wide
    
    echo ""
    echo "=== Pods in character-sheet namespace ==="
    kubectl get pods -n character-sheet -o wide
    
    echo ""
    echo "=== Services in character-sheet namespace ==="
    kubectl get svc -n character-sheet
    
    echo ""
    echo "=== Ingress ==="
    kubectl get ingress -n character-sheet
    
    # Get ALB DNS name
    echo ""
    echo "=== Application URLs ==="
    ALB_DNS=$(kubectl get ingress character-sheet-ingress -n character-sheet -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not available yet")
    if [ "$ALB_DNS" != "Not available yet" ]; then
        echo "Application URL: http://${ALB_DNS}"
        echo "Health Check: http://${ALB_DNS}/health"
        echo "API Base URL: http://${ALB_DNS}/api"
    else
        print_warning "ALB DNS not available yet. Please check again in a few minutes."
    fi
}

# Check application health
check_health() {
    print_status "Checking application health..."
    
    # Get ALB DNS name
    ALB_DNS=$(kubectl get ingress character-sheet-ingress -n character-sheet -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -z "$ALB_DNS" ]; then
        print_warning "ALB DNS not available yet. Skipping health check."
        return
    fi
    
    # Wait for ALB to be ready
    print_status "Waiting for ALB to be ready..."
    sleep 60
    
    # Check health endpoint
    if curl -f -s "http://${ALB_DNS}/health" >/dev/null; then
        print_success "Application health check passed"
    else
        print_warning "Application health check failed. The application might still be starting up."
    fi
}

# Main deployment function
deploy() {
    echo "=================================================="
    echo "Character Sheet EKS Deployment Script"
    echo "=================================================="
    echo "Project: ${PROJECT_NAME}"
    echo "Environment: ${ENVIRONMENT}"
    echo "AWS Region: ${AWS_REGION}"
    echo "Cluster Name: ${CLUSTER_NAME}"
    echo "=================================================="
    
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    install_alb_controller
    install_external_secrets
    deploy_application
    get_deployment_info
    check_health
    
    echo ""
    print_success "=== Deployment Complete ==="
    echo ""
    echo "Next steps:"
    echo "1. Wait a few minutes for all services to be fully ready"
    echo "2. Check application status: kubectl get all -n character-sheet"
    echo "3. View logs: kubectl logs -f deployment/backend-deployment -n character-sheet"
    echo "4. Access application via the ALB DNS name shown above"
    echo ""
    echo "For troubleshooting, see DEPLOYMENT_EKS.md"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up resources..."
    
    # Delete Kubernetes resources
    cd k8s
    kubectl delete -k . --ignore-not-found=true
    cd ..
    
    # Delete Terraform resources
    cd terraform
    terraform destroy -auto-approve
    cd ..
    
    print_success "Cleanup complete"
}

# Help function
show_help() {
    echo "Character Sheet EKS Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  deploy    Deploy the complete application (default)"
    echo "  cleanup   Remove all deployed resources"
    echo "  help      Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PROJECT_NAME   Project name (default: character-sheet)"
    echo "  ENVIRONMENT    Environment name (default: prod)"
    echo "  AWS_REGION     AWS region (default: us-west-2)"
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI configured with appropriate credentials"
    echo "  - Terraform >= 1.0"
    echo "  - kubectl"
    echo "  - Docker"
    echo "  - terraform.tfvars file configured"
}

# Main script logic
case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    cleanup)
        cleanup
        ;;
    help)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 