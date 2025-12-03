#!/bin/bash
set -e

# CNN Chile Infrastructure Destruction Script
# Version: 1.0
# Description: Safely destroy CNN Chile platform infrastructure

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

# Confirmation function
confirm_destruction() {
    echo
    warn "⚠️  DANGER: This will permanently destroy the CNN Chile infrastructure!"
    warn "This action cannot be undone!"
    echo
    log "This will delete:"
    echo "  • EKS cluster and all workloads"
    echo "  • RDS database (with data)"
    echo "  • DynamoDB tables (with data)"
    echo "  • S3 buckets (with content)"
    echo "  • CloudFront distributions"
    echo "  • All other AWS resources"
    echo
    
    read -p "Type 'DELETE' to confirm destruction: " confirmation
    if [ "$confirmation" != "DELETE" ]; then
        log "Destruction cancelled."
        exit 0
    fi
    
    read -p "Are you absolutely sure? (yes/no): " final_confirmation
    if [ "$final_confirmation" != "yes" ]; then
        log "Destruction cancelled."
        exit 0
    fi
}

# Backup critical data
backup_data() {
    log "Creating backup of critical data..."
    
    local backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Export DynamoDB tables
    log "Backing up DynamoDB tables..."
    local tables=(
        "${PROJECT_NAME}-users"
        "${PROJECT_NAME}-sessions"
        "${PROJECT_NAME}-subscriptions"
        "${PROJECT_NAME}-content"
        "${PROJECT_NAME}-analytics"
    )
    
    for table in "${tables[@]}"; do
        if aws dynamodb describe-table --table-name "$table" &>/dev/null; then
            log "Backing up table: $table"
            aws dynamodb scan --table-name "$table" > "$backup_dir/${table}.json"
        fi
    done
    
    # Export RDS data
    log "Creating RDS snapshot..."
    local db_identifier="${PROJECT_NAME}-database"
    local snapshot_id="${db_identifier}-final-snapshot-$(date +%Y%m%d-%H%M%S)"
    
    if aws rds describe-db-instances --db-instance-identifier "$db_identifier" &>/dev/null; then
        aws rds create-db-snapshot \
            --db-instance-identifier "$db_identifier" \
            --db-snapshot-identifier "$snapshot_id"
        
        log "RDS snapshot created: $snapshot_id"
    fi
    
    # List S3 buckets content
    log "Documenting S3 bucket contents..."
    local buckets=(
        "${PROJECT_NAME}-media-content"
        "${PROJECT_NAME}-static-content"
        "${PROJECT_NAME}-live-streaming"
    )
    
    for bucket in "${buckets[@]}"; do
        if aws s3 ls "s3://$bucket" &>/dev/null; then
            aws s3 ls "s3://$bucket" --recursive > "$backup_dir/${bucket}-contents.txt"
        fi
    done
    
    success "Backup created in: $backup_dir"
}

# Scale down Kubernetes resources
scale_down_kubernetes() {
    log "Scaling down Kubernetes resources..."
    
    # Check if cluster is accessible
    if ! kubectl get nodes &>/dev/null; then
        warn "EKS cluster not accessible, skipping Kubernetes cleanup"
        return
    fi
    
    # Scale down deployments
    log "Scaling down deployments..."
    kubectl scale deployment --all --replicas=0 -n cnn-chile 2>/dev/null || true
    
    # Delete persistent volume claims
    log "Deleting persistent volume claims..."
    kubectl delete pvc --all -n cnn-chile 2>/dev/null || true
    
    # Delete load balancer services to avoid hanging
    log "Deleting load balancer services..."
    kubectl delete service -l service.type=LoadBalancer --all-namespaces 2>/dev/null || true
    
    # Wait for load balancers to be deleted
    log "Waiting for load balancers to be deleted..."
    sleep 30
}

# Delete Kubernetes resources
delete_kubernetes() {
    log "Deleting Kubernetes resources..."
    
    if ! kubectl get nodes &>/dev/null; then
        warn "EKS cluster not accessible, skipping Kubernetes deletion"
        return
    fi
    
    # Delete ingress controller
    log "Deleting NGINX Ingress Controller..."
    helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || \
    kubectl delete namespace ingress-nginx 2>/dev/null || true
    
    # Delete application resources
    log "Deleting application resources..."
    kubectl delete -f "$KUBERNETES_DIR/microservices/" 2>/dev/null || true
    kubectl delete -f "$KUBERNETES_DIR/base/" 2>/dev/null || true
    
    # Delete namespaces
    log "Deleting namespaces..."
    kubectl delete namespace cnn-chile 2>/dev/null || true
    kubectl delete namespace monitoring 2>/dev/null || true
}

# Empty S3 buckets
empty_s3_buckets() {
    log "Emptying S3 buckets..."
    
    # Get list of S3 buckets created by Terraform
    local buckets
    buckets=$(aws s3 ls | grep "$PROJECT_NAME" | awk '{print $3}' || true)
    
    if [ -n "$buckets" ]; then
        echo "$buckets" | while read -r bucket; do
            if [ -n "$bucket" ]; then
                log "Emptying bucket: $bucket"
                aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true
                
                # Delete all versions if versioning is enabled
                aws s3api delete-objects \
                    --bucket "$bucket" \
                    --delete "$(aws s3api list-object-versions \
                        --bucket "$bucket" \
                        --output json \
                        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
                    2>/dev/null || true
                
                # Delete delete markers
                aws s3api delete-objects \
                    --bucket "$bucket" \
                    --delete "$(aws s3api list-object-versions \
                        --bucket "$bucket" \
                        --output json \
                        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
                    2>/dev/null || true
            fi
        done
    fi
}

# Destroy infrastructure with Terraform
destroy_infrastructure() {
    log "Destroying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform state exists
    if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -f "terraform.tfstate" ]; then
        # Try to initialize if state exists in remote backend
        terraform init 2>/dev/null || {
            warn "No Terraform state found. Infrastructure may already be destroyed."
            cd - > /dev/null
            return
        }
    fi
    
    # Destroy in reverse order to avoid dependencies
    log "Destroying Lambda functions and CloudFront distributions..."
    terraform destroy -target=aws_lambda_function.notification_service \
                     -target=aws_lambda_function.event_processor \
                     -target=aws_cloudfront_distribution.static_distribution \
                     -target=aws_cloudfront_distribution.media_distribution \
                     -auto-approve 2>/dev/null || true
    
    log "Destroying EKS cluster..."
    terraform destroy -target=aws_eks_node_group.main \
                     -target=aws_eks_cluster.main \
                     -auto-approve 2>/dev/null || true
    
    log "Destroying databases..."
    terraform destroy -target=aws_db_instance.main \
                     -target=aws_dynamodb_table.users \
                     -target=aws_dynamodb_table.sessions \
                     -target=aws_dynamodb_table.subscriptions \
                     -target=aws_elasticache_replication_group.main \
                     -auto-approve 2>/dev/null || true
    
    log "Destroying remaining resources..."
    terraform destroy -auto-approve
    
    success "Infrastructure destroyed successfully!"
    
    cd - > /dev/null
}

# Clean up local files
cleanup_local() {
    log "Cleaning up local files..."
    
    # Remove Terraform state and plans
    rm -f "$TERRAFORM_DIR/.terraform.lock.hcl" 2>/dev/null || true
    rm -rf "$TERRAFORM_DIR/.terraform/" 2>/dev/null || true
    rm -f "$TERRAFORM_DIR/terraform.tfstate*" 2>/dev/null || true
    rm -f "$TERRAFORM_DIR/tfplan" 2>/dev/null || true
    
    # Remove kubectl config context
    kubectl config delete-context "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${PROJECT_NAME}-cluster" 2>/dev/null || true
    
    success "Local cleanup completed!"
}

# Check AWS resources (shared helper function)
get_infrastructure_resources() {
    # Check EKS clusters - use query to get clean output
    local clusters
    clusters=$(aws eks list-clusters --query "clusters[*]" --output text 2>/dev/null | grep "${PROJECT_NAME}" || true)
    
    # Check RDS instances
    local db_instances
    db_instances=$(aws rds describe-db-instances --query "DBInstances[*].DBInstanceIdentifier" --output text 2>/dev/null | grep "${PROJECT_NAME}" || true)
    
    # Check DynamoDB tables - use query to get clean output
    local tables
    tables=$(aws dynamodb list-tables --query "TableNames[*]" --output text 2>/dev/null | grep "${PROJECT_NAME}" || true)
    
    # Check S3 buckets
    local buckets
    buckets=$(aws s3 ls 2>/dev/null | grep "${PROJECT_NAME}" | awk '{print $3}' || true)
    
    # Check CloudFront distributions - check both by Comment and by checking all distributions
    local distributions
    distributions=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '${PROJECT_NAME}')].Id" --output text 2>/dev/null || true)
    # Also check distributions by ID or other fields if comment-based check returns nothing
    if [ -z "$distributions" ]; then
        distributions=$(aws cloudfront list-distributions --query "DistributionList.Items[*].[Id,Comment]" --output text 2>/dev/null | grep "${PROJECT_NAME}" | awk '{print $1}' || true)
    fi
    
    # Return results as a string with pipe separators
    echo "${clusters}|${db_instances}|${tables}|${buckets}|${distributions}"
}

# Check if infrastructure already exists
check_infrastructure_status() {
    log "Checking current infrastructure status..."
    
    local resources_found=false
    local resource_data
    resource_data=$(get_infrastructure_resources)
    
    IFS='|' read -r clusters db_instances tables buckets distributions <<< "$resource_data"
    
    if [ -n "$clusters" ]; then
        log "Found EKS clusters: $clusters"
        resources_found=true
    fi
    
    if [ -n "$db_instances" ]; then
        log "Found RDS instances: $db_instances"
        resources_found=true
    fi
    
    if [ -n "$tables" ]; then
        log "Found DynamoDB tables: $tables"
        resources_found=true
    fi
    
    if [ -n "$buckets" ]; then
        log "Found S3 buckets: $buckets"
        resources_found=true
    fi
    
    if [ -n "$distributions" ]; then
        log "Found CloudFront distributions: $distributions"
        resources_found=true
    fi
    
    if [ "$resources_found" = false ]; then
        success "✅ Infrastructure is already destroyed. No resources found in AWS."
        return 0
    else
        log "Infrastructure resources found and will be destroyed."
        return 1
    fi
}

# Verify destruction
verify_destruction() {
    log "Verifying resource destruction..."
    
    local resource_data
    resource_data=$(get_infrastructure_resources)
    
    IFS='|' read -r clusters db_instances tables buckets distributions <<< "$resource_data"
    
    if [ -n "$clusters" ]; then
        warn "EKS clusters still exist: $clusters"
    fi
    
    if [ -n "$db_instances" ]; then
        warn "RDS instances still exist: $db_instances"
    fi
    
    if [ -n "$tables" ]; then
        warn "DynamoDB tables still exist: $tables"
    fi
    
    if [ -n "$buckets" ]; then
        warn "S3 buckets still exist: $buckets"
    fi
    
    if [ -n "$distributions" ]; then
        warn "CloudFront distributions still exist: $distributions"
    fi
    
    if [ -z "$clusters" ] && [ -z "$db_instances" ] && [ -z "$tables" ] && [ -z "$buckets" ] && [ -z "$distributions" ]; then
        success "All resources successfully destroyed!"
        return 0
    else
        warn "Some resources may still exist. Check AWS console for manual cleanup."
        return 1
    fi
}

# Main destruction function
main() {
    echo "=============================================="
    echo "   CNN Chile Infrastructure Destruction"
    echo "=============================================="
    echo
    
    # Parse command line arguments
    local skip_backup=false
    local force=false
    local check_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backup)
                skip_backup=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --check-status)
                check_only=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --skip-backup    Skip data backup before destruction"
                echo "  --force          Skip confirmation prompts"
                echo "  --check-status   Only check if infrastructure exists (don't destroy)"
                echo "  --help, -h       Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Set up environment
    export AWS_REGION=${AWS_REGION:-us-east-1}
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        error "Could not get AWS account ID. Please check your AWS credentials."
        exit 1
    fi
    
    # If check-only mode, just check status and exit
    if [ "$check_only" = true ]; then
        check_infrastructure_status
        exit $?
    fi
    
    # Check if infrastructure already exists
    if check_infrastructure_status; then
        # Infrastructure already destroyed, exit gracefully
        exit 0
    fi
    
    # Confirm destruction
    if [ "$force" = false ]; then
        confirm_destruction
    fi
    
    # Create backup unless skipped
    if [ "$skip_backup" = false ]; then
        backup_data
    fi
    
    # Execute destruction steps
    scale_down_kubernetes
    sleep 10
    delete_kubernetes
    sleep 30
    empty_s3_buckets
    destroy_infrastructure
    cleanup_local
    verify_destruction
    
    echo
    success "Destruction completed!"
    echo
    log "Remember to:"
    echo "1. Check AWS console for any remaining resources"
    echo "2. Review AWS billing for ongoing charges"
    echo "3. Delete any manual DNS records created"
    echo "4. Clean up any external service integrations"
    
    if [ "$skip_backup" = false ]; then
        echo "5. Archive the backup directory created earlier"
    fi
}

# Run main function with all arguments
main "$@"
