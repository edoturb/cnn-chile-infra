#!/bin/bash

# CNN Chile Infrastructure Health Check Script
# Version: 1.0
# Description: Comprehensive health check for CNN Chile platform

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="cnn-chile"

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

# Check AWS connectivity
check_aws() {
    log "Checking AWS connectivity..."
    
    if aws sts get-caller-identity &>/dev/null; then
        local account=$(aws sts get-caller-identity --query Account --output text)
        success "AWS connectivity OK - Account: $account"
        return 0
    else
        error "AWS connectivity failed"
        return 1
    fi
}

# Check EKS cluster health
check_eks() {
    log "Checking EKS cluster health..."
    
    local cluster_name="${PROJECT_NAME}-cluster"
    local region=${AWS_REGION:-us-east-1}
    
    # Check cluster status
    local cluster_status
    cluster_status=$(aws eks describe-cluster --name "$cluster_name" --region "$region" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$cluster_status" = "ACTIVE" ]; then
        success "EKS cluster status: $cluster_status"
    else
        error "EKS cluster status: $cluster_status"
        return 1
    fi
    
    # Check kubectl connectivity
    if kubectl get nodes &>/dev/null; then
        local node_count
        node_count=$(kubectl get nodes --no-headers | wc -l)
        success "kubectl connectivity OK - Nodes: $node_count"
        
        # Check node status
        local ready_nodes
        ready_nodes=$(kubectl get nodes --no-headers | grep -c Ready || echo "0")
        if [ "$ready_nodes" -eq "$node_count" ]; then
            success "All nodes ready ($ready_nodes/$node_count)"
        else
            warn "Some nodes not ready ($ready_nodes/$node_count)"
        fi
    else
        error "kubectl connectivity failed"
        return 1
    fi
    
    return 0
}

# Check pod health
check_pods() {
    log "Checking pod health..."
    
    local namespace="cnn-chile"
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &>/dev/null; then
        error "Namespace $namespace not found"
        return 1
    fi
    
    # Get pod status
    local pods
    pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pods" ]; then
        warn "No pods found in namespace $namespace"
        return 1
    fi
    
    echo "$pods" | while read -r line; do
        if [ -n "$line" ]; then
            local pod_name status ready
            pod_name=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $3}')
            ready=$(echo "$line" | awk '{print $2}')
            
            if [ "$status" = "Running" ] && [[ "$ready" == *"/"* ]]; then
                local ready_count total_count
                ready_count=$(echo "$ready" | cut -d'/' -f1)
                total_count=$(echo "$ready" | cut -d'/' -f2)
                
                if [ "$ready_count" = "$total_count" ]; then
                    success "Pod $pod_name: $status ($ready)"
                else
                    warn "Pod $pod_name: $status ($ready) - not fully ready"
                fi
            else
                error "Pod $pod_name: $status ($ready)"
            fi
        fi
    done
}

# Check service health
check_services() {
    log "Checking service health..."
    
    local namespace="cnn-chile"
    local services=("user-service" "content-service" "streaming-service" "payment-service" "api-gateway-service")
    
    for service in "${services[@]}"; do
        if kubectl get service "$service" -n "$namespace" &>/dev/null; then
            local cluster_ip
            cluster_ip=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.clusterIP}')
            success "Service $service: $cluster_ip"
        else
            error "Service $service not found"
        fi
    done
}

# Check ingress health
check_ingress() {
    log "Checking ingress health..."
    
    local namespace="cnn-chile"
    local ingress_name="cnn-chile-ingress"
    
    if kubectl get ingress "$ingress_name" -n "$namespace" &>/dev/null; then
        local lb_ip
        lb_ip=$(kubectl get ingress "$ingress_name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
        
        if [ "$lb_ip" != "pending" ] && [ -n "$lb_ip" ]; then
            success "Ingress $ingress_name: $lb_ip"
        else
            warn "Ingress $ingress_name: Load balancer IP pending"
        fi
    else
        error "Ingress $ingress_name not found"
    fi
}

# Check database connectivity
check_databases() {
    log "Checking database connectivity..."
    
    # Check RDS
    local db_identifier="${PROJECT_NAME}-database"
    local db_status
    db_status=$(aws rds describe-db-instances --db-instance-identifier "$db_identifier" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$db_status" = "available" ]; then
        success "RDS database: $db_status"
    else
        error "RDS database: $db_status"
    fi
    
    # Check DynamoDB tables
    local tables=("users" "sessions" "subscriptions" "content" "analytics")
    for table in "${tables[@]}"; do
        local table_name="${PROJECT_NAME}-${table}"
        local table_status
        table_status=$(aws dynamodb describe-table --table-name "$table_name" --query 'Table.TableStatus' --output text 2>/dev/null || echo "NOT_FOUND")
        
        if [ "$table_status" = "ACTIVE" ]; then
            success "DynamoDB table $table: $table_status"
        else
            error "DynamoDB table $table: $table_status"
        fi
    done
    
    # Check ElastiCache
    local redis_id="${PROJECT_NAME}-redis"
    local redis_status
    redis_status=$(aws elasticache describe-replication-groups --replication-group-id "$redis_id" --query 'ReplicationGroups[0].Status' --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$redis_status" = "available" ]; then
        success "ElastiCache Redis: $redis_status"
    else
        error "ElastiCache Redis: $redis_status"
    fi
}

# Check Lambda functions
check_lambda() {
    log "Checking Lambda functions..."
    
    local functions=("notification-service" "event-processor")
    
    for func in "${functions[@]}"; do
        local func_name="${PROJECT_NAME}-${func}"
        local func_state
        func_state=$(aws lambda get-function --function-name "$func_name" --query 'Configuration.State' --output text 2>/dev/null || echo "NOT_FOUND")
        
        if [ "$func_state" = "Active" ]; then
            success "Lambda function $func: $func_state"
        else
            error "Lambda function $func: $func_state"
        fi
    done
}

# Check CloudFront distributions
check_cloudfront() {
    log "Checking CloudFront distributions..."
    
    local distributions
    distributions=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment, '${PROJECT_NAME}')].[Id,Comment,Status]" --output text 2>/dev/null || echo "")
    
    if [ -n "$distributions" ]; then
        echo "$distributions" | while read -r line; do
            if [ -n "$line" ]; then
                local dist_id comment status
                dist_id=$(echo "$line" | awk '{print $1}')
                comment=$(echo "$line" | awk '{print $2}')
                status=$(echo "$line" | awk '{print $3}')
                
                if [ "$status" = "Deployed" ]; then
                    success "CloudFront distribution $comment: $status ($dist_id)"
                else
                    warn "CloudFront distribution $comment: $status ($dist_id)"
                fi
            fi
        done
    else
        warn "No CloudFront distributions found"
    fi
}

# Check S3 buckets
check_s3() {
    log "Checking S3 buckets..."
    
    local buckets
    buckets=$(aws s3 ls | grep "$PROJECT_NAME" | awk '{print $3}' || echo "")
    
    if [ -n "$buckets" ]; then
        echo "$buckets" | while read -r bucket; do
            if [ -n "$bucket" ]; then
                local region
                region=$(aws s3api get-bucket-location --bucket "$bucket" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")
                if [ "$region" = "None" ]; then
                    region="us-east-1"
                fi
                success "S3 bucket: $bucket (region: $region)"
            fi
        done
    else
        warn "No S3 buckets found"
    fi
}

# Check application endpoints
check_endpoints() {
    log "Checking application endpoints..."
    
    # Get load balancer DNS
    local lb_dns
    lb_dns=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -z "$lb_dns" ]; then
        warn "Load balancer DNS not available"
        return 1
    fi
    
    local endpoints=(
        "http://$lb_dns/health"
        "http://$lb_dns/api/v1/users/health"
        "http://$lb_dns/api/v1/content/health"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint" --connect-timeout 10 --max-time 30 || echo "000")
        
        if [ "$http_code" = "200" ]; then
            success "Endpoint $endpoint: HTTP $http_code"
        elif [ "$http_code" = "000" ]; then
            error "Endpoint $endpoint: Connection failed"
        else
            warn "Endpoint $endpoint: HTTP $http_code"
        fi
    done
}

# Check monitoring
check_monitoring() {
    log "Checking monitoring setup..."
    
    # Check CloudWatch log groups
    local log_groups=("application" "eks-cluster")
    
    for log_group in "${log_groups[@]}"; do
        local lg_name="/aws/${log_group}/${PROJECT_NAME}"
        if aws logs describe-log-groups --log-group-name-prefix "$lg_name" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$lg_name"; then
            success "CloudWatch log group: $lg_name"
        else
            warn "CloudWatch log group not found: $lg_name"
        fi
    done
    
    # Check CloudWatch dashboard
    local dashboard_name="${PROJECT_NAME}-dashboard"
    if aws cloudwatch get-dashboard --dashboard-name "$dashboard_name" &>/dev/null; then
        success "CloudWatch dashboard: $dashboard_name"
    else
        warn "CloudWatch dashboard not found: $dashboard_name"
    fi
}

# Generate health report
generate_report() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S UTC')
    
    echo
    echo "=============================================="
    echo "           Health Check Summary"
    echo "=============================================="
    echo "Timestamp: $timestamp"
    echo "Project: $PROJECT_NAME"
    echo "Region: ${AWS_REGION:-us-east-1}"
    echo
    
    # Count checks
    local total_checks=10
    local passed_checks=0
    
    echo "Health Check Results:"
    
    if check_aws; then ((passed_checks++)); fi
    if check_eks; then ((passed_checks++)); fi
    if check_pods; then ((passed_checks++)); fi
    if check_services; then ((passed_checks++)); fi
    if check_ingress; then ((passed_checks++)); fi
    if check_databases; then ((passed_checks++)); fi
    if check_lambda; then ((passed_checks++)); fi
    if check_cloudfront; then ((passed_checks++)); fi
    if check_s3; then ((passed_checks++)); fi
    if check_monitoring; then ((passed_checks++)); fi
    
    echo
    echo "Overall Status: $passed_checks/$total_checks checks passed"
    
    if [ "$passed_checks" -eq "$total_checks" ]; then
        success "All systems operational! 🎉"
        return 0
    elif [ "$passed_checks" -ge $((total_checks * 80 / 100)) ]; then
        warn "Most systems operational, some issues detected ⚠️"
        return 1
    else
        error "Multiple system failures detected! 🚨"
        return 2
    fi
}

# Main function
main() {
    echo "=============================================="
    echo "     CNN Chile Infrastructure Health Check"
    echo "=============================================="
    echo
    
    # Set up environment
    export AWS_REGION=${AWS_REGION:-us-east-1}
    
    # Parse command line arguments
    local check_endpoints_flag=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --endpoints)
                check_endpoints_flag=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --endpoints      Include application endpoint health checks"
                echo "  --verbose        Enable verbose output"
                echo "  --help, -h       Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Run health checks
    local exit_code
    generate_report
    exit_code=$?
    
    # Optional endpoint checks
    if [ "$check_endpoints_flag" = true ]; then
        echo
        check_endpoints
    fi
    
    exit $exit_code
}

# Run main function with all arguments
main "$@"
