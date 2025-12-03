#!/bin/bash
# Script to verify existing AWS resources for CNN Chile infrastructure
# This helps identify what resources already exist before running terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 CNN Chile Infrastructure - Resource Verification${NC}"
echo "=================================================="
echo ""

# Check AWS credentials
echo -e "${BLUE}🔐 Verificando credenciales AWS...${NC}"
if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓ Conectado a AWS${NC}"
    echo "  Account ID: $ACCOUNT_ID"
    echo "  User ARN: $USER_ARN"
else
    echo -e "${RED}✗ Error: No se puede conectar a AWS. Verifica tus credenciales.${NC}"
    exit 1
fi
echo ""

# Check region
REGION=${AWS_REGION:-us-east-1}
echo -e "${BLUE}📍 Región: ${REGION}${NC}"
echo ""

# Function to check if a resource exists
check_resource() {
    local resource_type=$1
    local command=$2
    local filter=$3
    
    echo -e "${BLUE}📦 Verificando ${resource_type}...${NC}"
    if output=$(eval "$command" 2>&1); then
        if [ -n "$filter" ]; then
            filtered=$(echo "$output" | eval "$filter")
            if [ -n "$filtered" ]; then
                echo -e "${GREEN}✓ Encontrado${NC}"
                echo "$filtered" | sed 's/^/  /'
            else
                echo -e "${YELLOW}⚠ No se encontraron recursos${NC}"
            fi
        else
            echo -e "${GREEN}✓ Encontrado${NC}"
            echo "$output" | sed 's/^/  /'
        fi
    else
        echo -e "${RED}✗ Error al verificar${NC}"
        echo "$output" | sed 's/^/  /' >&2
    fi
    echo ""
}

# Check EKS Cluster
echo -e "${BLUE}☸️  EKS Clusters:${NC}"
echo "=================================================="
aws eks list-clusters --region $REGION --query 'clusters' --output table 2>/dev/null || echo "No clusters found or insufficient permissions"

# Check specific cluster
CLUSTER_NAME="confused-bluegrass-walrus"
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Cluster '$CLUSTER_NAME' encontrado${NC}"
    aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
        --query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint,RoleArn:roleArn}' \
        --output table | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠ Cluster '$CLUSTER_NAME' no encontrado${NC}"
fi
echo ""

# Check IAM Roles
echo -e "${BLUE}👤 IAM Roles (Lab roles):${NC}"
echo "=================================================="
aws iam list-roles --query 'Roles[?contains(RoleName, `Lab`) || contains(RoleName, `EKS`)].{Name:RoleName,ARN:Arn}' \
    --output table 2>/dev/null | head -20 || echo "Insufficient permissions to list roles"
echo ""

# Check VPCs
echo -e "${BLUE}🌐 VPCs:${NC}"
echo "=================================================="
aws ec2 describe-vpcs --region $REGION \
    --query 'Vpcs[*].{VpcId:VpcId,CIDR:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value,Default:IsDefault}' \
    --output table 2>/dev/null || echo "No VPCs found or insufficient permissions"
echo ""

# Check Subnets
echo -e "${BLUE}📡 Subnets (primeras 10):${NC}"
echo "=================================================="
aws ec2 describe-subnets --region $REGION \
    --query 'Subnets[0:10].{SubnetId:SubnetId,VPC:VpcId,CIDR:CidrBlock,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}' \
    --output table 2>/dev/null || echo "No subnets found or insufficient permissions"
echo ""

# Check Security Groups
echo -e "${BLUE}🔒 Security Groups (con CNN o EKS en nombre):${NC}"
echo "=================================================="
aws ec2 describe-security-groups --region $REGION \
    --query 'SecurityGroups[?contains(GroupName, `cnn`) || contains(GroupName, `CNN`) || contains(GroupName, `eks`) || contains(GroupName, `EKS`)].{ID:GroupId,Name:GroupName,VPC:VpcId}' \
    --output table 2>/dev/null || echo "No matching security groups found"
echo ""

# Check S3 Buckets
echo -e "${BLUE}💾 S3 Buckets (con 'cnn' en nombre):${NC}"
echo "=================================================="
aws s3 ls 2>/dev/null | grep -i cnn || echo "No CNN buckets found"
echo ""

# Check DynamoDB Tables
echo -e "${BLUE}🗄️  DynamoDB Tables:${NC}"
echo "=================================================="
aws dynamodb list-tables --region $REGION --output table 2>/dev/null || echo "No tables found or insufficient permissions"
echo ""

# Check ElastiCache
echo -e "${BLUE}⚡ ElastiCache Redis:${NC}"
echo "=================================================="
aws elasticache describe-replication-groups --region $REGION \
    --query 'ReplicationGroups[*].{ID:ReplicationGroupId,Status:Status,Engine:CacheNodeType,Endpoint:NodeGroups[0].PrimaryEndpoint.Address}' \
    --output table 2>/dev/null || echo "No ElastiCache clusters found or insufficient permissions"
echo ""

# Check RDS Instances
echo -e "${BLUE}🐘 RDS Instances:${NC}"
echo "=================================================="
aws rds describe-db-instances --region $REGION \
    --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Version:EngineVersion,Class:DBInstanceClass}' \
    --output table 2>/dev/null || echo "No RDS instances found or insufficient permissions"
echo ""

# Check Load Balancers
echo -e "${BLUE}⚖️  Application Load Balancers:${NC}"
echo "=================================================="
aws elbv2 describe-load-balancers --region $REGION \
    --query 'LoadBalancers[*].{Name:LoadBalancerName,DNS:DNSName,State:State.Code,Type:Type}' \
    --output table 2>/dev/null || echo "No load balancers found or insufficient permissions"
echo ""

# Check Lambda Functions
echo -e "${BLUE}λ Lambda Functions:${NC}"
echo "=================================================="
aws lambda list-functions --region $REGION \
    --query 'Functions[*].{Name:FunctionName,Runtime:Runtime,LastModified:LastModified}' \
    --output table 2>/dev/null || echo "No lambda functions found or insufficient permissions"
echo ""

# Check CloudFront Distributions
echo -e "${BLUE}🌍 CloudFront Distributions:${NC}"
echo "=================================================="
aws cloudfront list-distributions \
    --query 'DistributionList.Items[*].{ID:Id,DomainName:DomainName,Status:Status,Enabled:Enabled}' \
    --output table 2>/dev/null || echo "No CloudFront distributions found or insufficient permissions"
echo ""

# Check Secrets Manager
echo -e "${BLUE}🔑 Secrets Manager:${NC}"
echo "=================================================="
aws secretsmanager list-secrets --region $REGION \
    --query 'SecretList[*].{Name:Name,LastChanged:LastChangedDate}' \
    --output table 2>/dev/null || echo "No secrets found or insufficient permissions"
echo ""

# Check CloudWatch Log Groups
echo -e "${BLUE}📊 CloudWatch Log Groups (con 'cnn' o 'eks'):${NC}"
echo "=================================================="
aws logs describe-log-groups --region $REGION \
    --query 'logGroups[?contains(logGroupName, `cnn`) || contains(logGroupName, `eks`)].{Name:logGroupName,Size:storedBytes}' \
    --output table 2>/dev/null || echo "No matching log groups found"
echo ""

# Check SNS Topics
echo -e "${BLUE}📧 SNS Topics:${NC}"
echo "=================================================="
aws sns list-topics --region $REGION --output table 2>/dev/null || echo "No SNS topics found or insufficient permissions"
echo ""

# Check SQS Queues
echo -e "${BLUE}📬 SQS Queues:${NC}"
echo "=================================================="
aws sqs list-queues --region $REGION 2>/dev/null || echo "No SQS queues found or insufficient permissions"
echo ""

# Check WAF
echo -e "${BLUE}🛡️  WAF Web ACLs:${NC}"
echo "=================================================="
aws wafv2 list-web-acls --scope REGIONAL --region $REGION \
    --query 'WebACLs[*].{Name:Name,ID:Id}' \
    --output table 2>/dev/null || echo "No WAF ACLs found or insufficient permissions"
echo ""

# Summary
echo "=================================================="
echo -e "${BLUE}📋 Resumen de Verificación${NC}"
echo "=================================================="
echo -e "${GREEN}✓${NC} Verificación completada"
echo ""
echo "Próximos pasos recomendados:"
echo "  1. Revisar el output anterior para identificar recursos existentes"
echo "  2. Configurar kubectl para el cluster EKS si existe:"
echo "     ${YELLOW}aws eks update-kubeconfig --region $REGION --name confused-bluegrass-walrus${NC}"
echo "  3. Consultar EKS-INTEGRATION-GUIDE.md para instrucciones detalladas"
echo "  4. Ejecutar terraform plan para ver qué recursos se crearían:"
echo "     ${YELLOW}cd terraform && terraform plan -var-file=terraform.tfvars${NC}"
echo ""
