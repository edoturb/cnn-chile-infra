#!/bin/bash
set -e

# CNN Chile Infrastructure Deployment Script
# Version: 1.0
# Description: Automated deployment script for CNN Chile platform infrastructure

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="cnn-chile"
TERRAFORM_DIR="./terraform"
KUBERNETES_DIR="./kubernetes"
LAMBDA_DIR="./lambda"

# Functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if AWS CLI is installed and configured
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure'"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    success "All prerequisites met!"
}

# Setup environment variables
setup_environment() {
    log "Setting up environment variables..."
    
    # Get AWS account info
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    export AWS_REGION=${AWS_REGION:-us-east-1}
    
    log "AWS Account ID: $AWS_ACCOUNT_ID"
    log "AWS Region: $AWS_REGION"
    
    # Set Terraform variables
    export TF_VAR_project_name=$PROJECT_NAME
    export TF_VAR_aws_region=$AWS_REGION
    
    # Check if terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        warn "terraform.tfvars not found. Creating template..."
        create_tfvars_template
    fi
}

# Create terraform.tfvars template
create_tfvars_template() {
    cat > "$TERRAFORM_DIR/terraform.tfvars" << EOF
# CNN Chile Infrastructure Configuration
aws_region = "$AWS_REGION"
environment = "dev"
project_name = "$PROJECT_NAME"

# Database Configuration
rds_instance_class = "db.t3.micro"
rds_allocated_storage = 20

# EKS Configuration
eks_node_instance_types = ["t3.medium"]
eks_node_desired_capacity = 2
eks_node_max_capacity = 5
eks_node_min_capacity = 1

# OAuth Configuration (Update with real values)
google_client_id = ""
facebook_app_id = ""

# Environment-specific settings
enable_nat_gateway = true
single_nat_gateway = true
EOF
    warn "Please update $TERRAFORM_DIR/terraform.tfvars with your specific values before proceeding."
    read -p "Press Enter to continue after updating the values..."
}

# Setup Terraform backend
setup_terraform_backend() {
    log "Setting up Terraform backend..."
    
    local bucket_name="${PROJECT_NAME}-terraform-state-${AWS_ACCOUNT_ID}"
    
    # Create S3 bucket for Terraform state if it doesn't exist
    if ! aws s3 ls "s3://$bucket_name" 2>&1 > /dev/null; then
        log "Creating S3 bucket for Terraform state: $bucket_name"
        
        if [ "$AWS_REGION" == "us-east-1" ]; then
            aws s3 mb "s3://$bucket_name"
        else
            aws s3 mb "s3://$bucket_name" --region "$AWS_REGION"
        fi
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Enable encryption
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }'
        
        success "Terraform state bucket created: $bucket_name"
    else
        log "Terraform state bucket already exists: $bucket_name"
    fi
    
    # Update backend configuration
    sed -i.bak "s/cnn-chile-terraform-state/$bucket_name/g" "$TERRAFORM_DIR/main.tf"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    log "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Confirm deployment
    echo
    read -p "Do you want to proceed with the infrastructure deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Deployment cancelled by user."
        exit 0
    fi
    
    # Apply in stages to avoid timeouts
    log "Deploying VPC and networking..."
    terraform apply -target=aws_vpc.main \
                   -target=aws_subnet.private \
                   -target=aws_subnet.public \
                   -target=aws_subnet.database \
                   -target=aws_internet_gateway.main \
                   -target=aws_nat_gateway.main \
                   -target=aws_route_table.public \
                   -target=aws_route_table.private \
                   -auto-approve
    
    log "Deploying security groups..."
    terraform apply -target=aws_security_group.eks_cluster \
                   -target=aws_security_group.eks_nodes \
                   -target=aws_security_group.rds \
                   -target=aws_security_group.lambda \
                   -target=aws_security_group.alb \
                   -auto-approve
    
    log "Deploying EKS cluster..."
    terraform apply -target=aws_eks_cluster.main \
                   -target=aws_eks_node_group.main \
                   -auto-approve
    
    log "Deploying databases..."
    terraform apply -target=aws_db_instance.main \
                   -target=aws_dynamodb_table.users \
                   -target=aws_dynamodb_table.sessions \
                   -target=aws_dynamodb_table.subscriptions \
                   -target=aws_elasticache_replication_group.main \
                   -auto-approve
    
    log "Deploying remaining infrastructure..."
    terraform apply -auto-approve
    
    success "Infrastructure deployment completed!"
    
    cd - > /dev/null
}

# Configure kubectl for EKS
configure_kubectl() {
    log "Configuring kubectl for EKS cluster..."
    
    local cluster_name="${PROJECT_NAME}-cluster"
    
    # Update kubeconfig
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$cluster_name"
    
    # Verify connection
    if kubectl get nodes &> /dev/null; then
        success "kubectl configured successfully!"
        kubectl get nodes
    else
        error "Failed to connect to EKS cluster"
        exit 1
    fi
}

# Deploy Kubernetes resources
deploy_kubernetes() {
    log "Deploying Kubernetes resources..."
    
    cd "$KUBERNETES_DIR"
    
    # Create namespaces
    log "Creating namespaces..."
    kubectl apply -f base/namespaces.yaml
    
    # Update secrets with real values from AWS
    log "Setting up secrets from AWS Secrets Manager..."
    update_kubernetes_secrets
    
    # Apply configmaps
    log "Applying configmaps..."
    kubectl apply -f base/configmaps.yaml
    
    # Deploy microservices
    log "Deploying microservices..."
    kubectl apply -f microservices/user-service.yaml
    kubectl apply -f microservices/content-service.yaml
    kubectl apply -f microservices/streaming-service.yaml
    kubectl apply -f microservices/payment-service.yaml
    kubectl apply -f microservices/api-gateway.yaml
    
    # Install NGINX Ingress Controller
    log "Installing NGINX Ingress Controller..."
    install_ingress_controller
    
    # Apply ingress rules
    log "Applying ingress rules..."
    kubectl apply -f base/ingress.yaml
    
    # Wait for pods to be ready
    log "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=user-service -n cnn-chile --timeout=300s
    kubectl wait --for=condition=ready pod -l app=content-service -n cnn-chile --timeout=300s
    kubectl wait --for=condition=ready pod -l app=api-gateway -n cnn-chile --timeout=300s
    
    success "Kubernetes resources deployed successfully!"
    
    cd - > /dev/null
}

# Update Kubernetes secrets with values from AWS
update_kubernetes_secrets() {
    log "Retrieving secrets from AWS Secrets Manager..."
    
    # Get database credentials
    local db_secret=$(aws secretsmanager get-secret-value \
        --secret-id "${PROJECT_NAME}-db-password" \
        --query SecretString --output text)
    
    local db_host=$(echo "$db_secret" | jq -r .endpoint)
    local db_port=$(echo "$db_secret" | jq -r .port)
    local db_name=$(echo "$db_secret" | jq -r .dbname)
    local db_user=$(echo "$db_secret" | jq -r .username)
    local db_password=$(echo "$db_secret" | jq -r .password)
    
    # Get Redis credentials
    local redis_secret=$(aws secretsmanager get-secret-value \
        --secret-id "${PROJECT_NAME}-redis-auth" \
        --query SecretString --output text)
    
    local redis_host=$(echo "$redis_secret" | jq -r .endpoint)
    local redis_port=$(echo "$redis_secret" | jq -r .port)
    local redis_auth=$(echo "$redis_secret" | jq -r .auth_token)
    
    # Create database secret
    kubectl create secret generic database-secrets \
        --from-literal=DB_HOST="$db_host" \
        --from-literal=DB_PORT="$db_port" \
        --from-literal=DB_NAME="$db_name" \
        --from-literal=DB_USER="$db_user" \
        --from-literal=DB_PASSWORD="$db_password" \
        --namespace=cnn-chile \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Redis secret
    kubectl create secret generic redis-secrets \
        --from-literal=REDIS_HOST="$redis_host" \
        --from-literal=REDIS_PORT="$redis_port" \
        --from-literal=REDIS_AUTH_TOKEN="$redis_auth" \
        --namespace=cnn-chile \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create JWT secret (generate random)
    local jwt_secret=$(openssl rand -base64 32)
    local jwt_refresh_secret=$(openssl rand -base64 32)
    
    kubectl create secret generic jwt-secrets \
        --from-literal=JWT_SECRET="$jwt_secret" \
        --from-literal=JWT_REFRESH_SECRET="$jwt_refresh_secret" \
        --namespace=cnn-chile \
        --dry-run=client -o yaml | kubectl apply -f -
}

# Install NGINX Ingress Controller
install_ingress_controller() {
    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        warn "Helm not found. Installing NGINX Ingress Controller via kubectl..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
    else
        log "Installing NGINX Ingress Controller via Helm..."
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update
        
        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.service.type=LoadBalancer \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
    fi
    
    # Wait for load balancer to be ready
    log "Waiting for load balancer to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
}

# Post-deployment validation
validate_deployment() {
    log "Validating deployment..."
    
    # Check EKS cluster
    log "Checking EKS cluster status..."
    kubectl get nodes
    
    # Check pod status
    log "Checking pod status..."
    kubectl get pods -n cnn-chile
    
    # Check services
    log "Checking services..."
    kubectl get services -n cnn-chile
    
    # Get load balancer DNS name
    local lb_dns
    lb_dns=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -n "$lb_dns" ]; then
        success "Load Balancer DNS: $lb_dns"
        log "Configure your DNS to point to this load balancer"
    else
        warn "Load balancer DNS not yet available. Check again in a few minutes."
    fi
    
    # Health check endpoints (will fail initially until DNS is configured)
    log "Health check endpoints (configure DNS first):"
    echo "  - https://api.cnnchile.com/health"
    echo "  - https://api.cnnchile.com/api/v1/users/health"
    echo "  - https://api.cnnchile.com/api/v1/content/health"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    rm -f "$TERRAFORM_DIR/tfplan"
    rm -f "$TERRAFORM_DIR/main.tf.bak"
}

# Main deployment function
main() {
    echo "=============================================="
    echo "   CNN Chile Infrastructure Deployment"
    echo "=============================================="
    echo
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Parse command line arguments
    local skip_infra=false
    local skip_k8s=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-infrastructure)
                skip_infra=true
                shift
                ;;
            --skip-kubernetes)
                skip_k8s=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --skip-infrastructure  Skip Terraform infrastructure deployment"
                echo "  --skip-kubernetes     Skip Kubernetes deployment"
                echo "  --help, -h           Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute deployment steps
    check_prerequisites
    setup_environment
    
    if [ "$skip_infra" = false ]; then
        setup_terraform_backend
        deploy_infrastructure
        configure_kubectl
    else
        log "Skipping infrastructure deployment"
        configure_kubectl
    fi
    
    if [ "$skip_k8s" = false ]; then
        deploy_kubernetes
    else
        log "Skipping Kubernetes deployment"
    fi
    
    validate_deployment
    
    echo
    success "Deployment completed successfully!"
    echo
    log "Next steps:"
    echo "1. Configure DNS records to point to the load balancer"
    echo "2. Update SSL certificates if needed"
    echo "3. Configure external service integrations (Stripe, OAuth providers)"
    echo "4. Run health checks and monitoring setup"
    echo
    log "For detailed instructions, see: docs/deployment-guide.md"
}

# Run main function with all arguments
main "$@"
