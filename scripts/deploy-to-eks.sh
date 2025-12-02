#!/bin/bash
set -e

# Script para desplegar CNN Chile en EKS
# Autor: DevOps Team CNN Chile
# Fecha: $(date +%Y-%m-%d)

echo "🚀 Iniciando despliegue de CNN Chile en EKS..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Variables
CLUSTER_NAME="confused-bluegrass-walrus"
NAMESPACE="cnn-chile"
AWS_REGION="us-east-1"

# Función para verificar prerequisites
check_prerequisites() {
    log_info "Verificando prerequisites..."
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl no está instalado. Instalando..."
        curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.28.3/2023-11-14/bin/darwin/amd64/kubectl
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin
    fi
    
    # Verificar AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI no está instalado. Por favor instalar primero."
        exit 1
    fi
    
    # Verificar conexión al cluster
    log_info "Configurando acceso al cluster EKS..."
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "No se puede conectar al cluster EKS. Verificar configuración."
        exit 1
    fi
    
    log_success "Prerequisites verificados correctamente"
}

# Función para crear namespace
create_namespace() {
    log_info "Creando namespace $NAMESPACE..."
    kubectl apply -f kubernetes/deployment/cnn-chile-app.yaml --dry-run=client -o yaml | head -10
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    name: $NAMESPACE
    environment: dev
EOF
    log_success "Namespace $NAMESPACE creado"
}

# Función para aplicar manifiestos
apply_manifests() {
    log_info "Aplicando manifiestos de Kubernetes..."
    
    # Aplicar secretos y configuraciones
    kubectl apply -f kubernetes/config/secrets.yaml
    log_success "Secretos aplicados"
    
    kubectl apply -f kubernetes/config/configmaps.yaml
    log_success "ConfigMaps aplicados"
    
    kubectl apply -f kubernetes/config/app-code.yaml
    log_success "Código de aplicación cargado"
    
    # Aplicar deployments
    kubectl apply -f kubernetes/deployment/backend-services.yaml
    log_success "Servicios backend desplegados"
    
    kubectl apply -f kubernetes/deployment/cnn-chile-app.yaml
    log_success "Aplicación frontend desplegada"
}

# Función para verificar el despliegue
verify_deployment() {
    log_info "Verificando estado del despliegue..."
    
    # Esperar a que los pods estén listos
    log_info "Esperando a que los pods estén listos..."
    kubectl wait --for=condition=ready pod -l app=cnn-chile-web -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=cnn-chile-api -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=cnn-chile-streaming -n $NAMESPACE --timeout=300s
    
    # Mostrar estado de los recursos
    echo ""
    log_info "Estado de los pods:"
    kubectl get pods -n $NAMESPACE -o wide
    
    echo ""
    log_info "Estado de los servicios:"
    kubectl get services -n $NAMESPACE
    
    echo ""
    log_info "Estado del ingress:"
    kubectl get ingress -n $NAMESPACE
    
    log_success "Verificación completada"
}

# Función para mostrar información de acceso
show_access_info() {
    echo ""
    log_info "🎯 Información de acceso a la aplicación:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Obtener información del Load Balancer
    LB_HOSTNAME=$(kubectl get ingress cnn-chile-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pendiente...")
    
    echo "📱 Aplicación Web: http://$LB_HOSTNAME"
    echo "🔌 API Endpoint: http://$LB_HOSTNAME/api/"
    echo "📺 Streaming: http://$LB_HOSTNAME/streaming/"
    echo ""
    echo "🔧 Para monitoreo en tiempo real:"
    echo "   kubectl logs -f deployment/cnn-chile-web -n $NAMESPACE"
    echo "   kubectl logs -f deployment/cnn-chile-api -n $NAMESPACE"
    echo ""
    echo "🎛️  Para acceder al dashboard de Kubernetes:"
    echo "   kubectl proxy"
    echo "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Función principal
main() {
    echo "🏗️  CNN Chile - Despliegue en EKS"
    echo "=================================="
    echo ""
    
    check_prerequisites
    create_namespace
    apply_manifests
    verify_deployment
    show_access_info
    
    echo ""
    log_success "🎉 ¡Despliegue de CNN Chile completado exitosamente!"
    log_info "La aplicación está ahora ejecutándose en Amazon EKS"
}

# Ejecutar función principal
main "$@"
