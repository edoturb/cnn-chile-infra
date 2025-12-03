#!/bin/bash
# Script to configure Terraform to use existing EKS cluster
# This script helps integrate the manually created EKS cluster with Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="confused-bluegrass-walrus"
REGION="us-east-1"
TERRAFORM_DIR="../terraform"

echo -e "${BLUE}🔧 Configurador de Cluster EKS Existente${NC}"
echo "============================================"
echo ""

# Check prerequisites
echo -e "${BLUE}📋 Verificando prerrequisitos...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI no está instalado${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl no está instalado${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform no está instalado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Todas las herramientas están instaladas${NC}"
echo ""

# Verify AWS credentials
echo -e "${BLUE}🔐 Verificando credenciales AWS...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ No se puede conectar a AWS. Verifica tus credenciales.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ Conectado a AWS Account: $ACCOUNT_ID${NC}"
echo ""

# Check if cluster exists
echo -e "${BLUE}☸️  Verificando cluster EKS existente...${NC}"
if ! aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
    echo -e "${RED}✗ Cluster '$CLUSTER_NAME' no encontrado en región $REGION${NC}"
    echo "Verifica que el cluster existe:"
    echo "  aws eks list-clusters --region $REGION"
    exit 1
fi

# Get cluster details
CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
CLUSTER_VERSION=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.version' --output text)
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.endpoint' --output text)
CLUSTER_ARN=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.arn' --output text)
CLUSTER_ROLE_ARN=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.roleArn' --output text)

echo -e "${GREEN}✓ Cluster encontrado${NC}"
echo "  Nombre: $CLUSTER_NAME"
echo "  Estado: $CLUSTER_STATUS"
echo "  Versión: $CLUSTER_VERSION"
echo "  ARN: $CLUSTER_ARN"
echo ""

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo -e "${YELLOW}⚠ ADVERTENCIA: El cluster no está en estado ACTIVE${NC}"
    echo "Estado actual: $CLUSTER_STATUS"
    echo "Espera a que el cluster esté activo antes de continuar."
    read -p "¿Deseas continuar de todas formas? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Configure kubectl
echo -e "${BLUE}⚙️  Configurando kubectl...${NC}"
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ kubectl configurado correctamente${NC}"
    echo ""
    echo "Información del cluster:"
    kubectl cluster-info | head -5
else
    echo -e "${YELLOW}⚠ kubectl configurado, pero no se pudo conectar al cluster${NC}"
    echo "Esto es normal si el cluster aún se está inicializando."
fi
echo ""

# Offer to update Terraform configuration
echo -e "${BLUE}🔧 Configuración de Terraform${NC}"
echo "============================================"
echo ""
echo "Este script puede configurar Terraform para usar el cluster existente."
echo "Esto implica:"
echo "  1. Habilitar data sources en terraform/eks-existing.tf"
echo "  2. Crear un archivo de respaldo de eks.tf"
echo "  3. Comentar recursos que crean un nuevo cluster en eks.tf"
echo ""
read -p "¿Deseas configurar Terraform automáticamente? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd $TERRAFORM_DIR
    
    # Backup eks.tf
    if [ -f eks.tf ]; then
        echo -e "${BLUE}📦 Creando backup de eks.tf...${NC}"
        cp eks.tf eks.tf.backup-$(date +%Y%m%d-%H%M%S)
        echo -e "${GREEN}✓ Backup creado${NC}"
    fi
    
    # Check if eks-existing.tf needs to be uncommented
    if grep -q "^/\*" eks-existing.tf; then
        echo -e "${BLUE}✏️  Habilitando data sources en eks-existing.tf...${NC}"
        
        # Remove comment markers
        sed -i 's|^/\*||g' eks-existing.tf
        sed -i 's|\*/||g' eks-existing.tf
        
        echo -e "${GREEN}✓ Data sources habilitados${NC}"
    else
        echo -e "${YELLOW}⚠ eks-existing.tf ya está configurado${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Terraform configurado${NC}"
    echo ""
    echo "IMPORTANTE: Debes hacer lo siguiente manualmente:"
    echo "  1. Editar terraform/main.tf para actualizar los providers"
    echo "  2. Comentar o eliminar recursos de creación de cluster en eks.tf"
    echo ""
    echo "Consulta EKS-INTEGRATION-GUIDE.md para instrucciones detalladas."
else
    echo -e "${YELLOW}⚠ Configuración manual de Terraform omitida${NC}"
    echo "Consulta EKS-INTEGRATION-GUIDE.md para hacerlo manualmente."
fi

echo ""
echo "============================================"
echo -e "${GREEN}✅ Configuración completada${NC}"
echo "============================================"
echo ""
echo "📝 Próximos pasos recomendados:"
echo ""
echo "1. Verificar recursos existentes:"
echo "   ${YELLOW}./scripts/verify-resources.sh${NC}"
echo ""
echo "2. Desplegar aplicaciones al cluster:"
echo "   ${YELLOW}kubectl create namespace cnn-chile-dev${NC}"
echo "   ${YELLOW}./scripts/deploy-to-eks.sh${NC}"
echo ""
echo "3. Verificar el despliegue:"
echo "   ${YELLOW}kubectl get pods -n cnn-chile-dev${NC}"
echo "   ${YELLOW}kubectl get services -n cnn-chile-dev${NC}"
echo ""
echo "4. (Opcional) Completar recursos con Terraform:"
echo "   ${YELLOW}cd terraform${NC}"
echo "   ${YELLOW}terraform plan -var-file=terraform.tfvars${NC}"
echo ""
echo "📚 Documentación:"
echo "   - Guía rápida: QUICK-START.md"
echo "   - Guía completa: COMPLETE-DEPLOYMENT-GUIDE.md"
echo "   - Integración EKS: EKS-INTEGRATION-GUIDE.md"
echo ""
echo "🎉 ¡Tu cluster EKS está listo para usar!"
echo ""
