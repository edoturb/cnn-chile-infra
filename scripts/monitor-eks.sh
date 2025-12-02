#!/bin/bash
set -e

# Script para monitorear la creación del cluster EKS
# CNN Chile Infrastructure

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
CLUSTER_NAME="confused-bluegrass-walrus"
AWS_REGION="us-east-1"
MAX_WAIT_TIME=1800  # 30 minutos máximo

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"
}

# Función para obtener estado del cluster
get_cluster_status() {
    aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query 'cluster.status' --output text 2>/dev/null || echo "ERROR"
}

# Función para obtener endpoint del cluster
get_cluster_endpoint() {
    aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query 'cluster.endpoint' --output text 2>/dev/null || echo "null"
}

# Función para mostrar información del cluster
show_cluster_info() {
    log_info "📊 Información del Cluster EKS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    CLUSTER_INFO=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        STATUS=$(echo $CLUSTER_INFO | jq -r '.cluster.status')
        VERSION=$(echo $CLUSTER_INFO | jq -r '.cluster.version')
        ENDPOINT=$(echo $CLUSTER_INFO | jq -r '.cluster.endpoint // "Pendiente..."')
        CREATED=$(echo $CLUSTER_INFO | jq -r '.cluster.createdAt')
        
        echo "🏷️  Nombre: $CLUSTER_NAME"
        echo "📍 Estado: $STATUS"
        echo "🔄 Versión K8s: $VERSION"
        echo "🌐 Endpoint: $ENDPOINT"
        echo "📅 Creado: $CREATED"
    else
        log_error "No se puede obtener información del cluster"
        return 1
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Función principal de monitoreo
monitor_cluster() {
    log_info "🚀 Iniciando monitoreo del cluster EKS: $CLUSTER_NAME"
    
    show_cluster_info
    
    START_TIME=$(date +%s)
    DOTS=""
    
    while true; do
        STATUS=$(get_cluster_status)
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))
        
        # Agregar puntos animados
        DOTS="${DOTS}."
        if [ ${#DOTS} -gt 3 ]; then
            DOTS=""
        fi
        
        case $STATUS in
            "ACTIVE")
                echo ""
                log_success "✅ ¡Cluster EKS está ACTIVO!"
                
                # Configurar kubectl
                log_info "🔧 Configurando kubectl..."
                if aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME; then
                    log_success "✅ kubectl configurado correctamente"
                    
                    # Verificar conectividad
                    log_info "🔍 Verificando conectividad..."
                    if kubectl cluster-info --request-timeout=10s > /dev/null 2>&1; then
                        log_success "✅ Conectividad verificada"
                        
                        # Mostrar información de nodos
                        log_info "📊 Información de nodos:"
                        kubectl get nodes -o wide || log_warning "⚠️  Nodos aún no disponibles (modo automático)"
                        
                        # Instrucciones finales
                        echo ""
                        log_success "🎯 Próximos pasos:"
                        echo "   1. Ejecutar: ./scripts/deploy-to-eks.sh"
                        echo "   2. Monitorear: kubectl get pods -A"
                        echo "   3. Acceder app: kubectl get ingress -A"
                        
                        return 0
                    else
                        log_warning "⚠️  Cluster activo pero aún no responde"
                    fi
                else
                    log_error "❌ Error configurando kubectl"
                    return 1
                fi
                ;;
                
            "CREATING")
                printf "\r${BLUE}[$(date +'%H:%M:%S')]${NC} ⏳ Creando cluster${DOTS} (${ELAPSED}s transcurridos)"
                ;;
                
            "FAILED")
                echo ""
                log_error "❌ Error: El cluster falló en la creación"
                return 1
                ;;
                
            "ERROR")
                echo ""
                log_error "❌ Error consultando el estado del cluster"
                return 1
                ;;
                
            *)
                printf "\r${YELLOW}[$(date +'%H:%M:%S')]${NC} 🔄 Estado: $STATUS${DOTS} (${ELAPSED}s)"
                ;;
        esac
        
        # Timeout después de MAX_WAIT_TIME
        if [ $ELAPSED -gt $MAX_WAIT_TIME ]; then
            echo ""
            log_error "❌ Timeout: El cluster no se activó en $MAX_WAIT_TIME segundos"
            return 1
        fi
        
        sleep 5
    done
}

# Función para verificar prerequisites
check_prerequisites() {
    log_info "🔍 Verificando prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI no está instalado"
        return 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_info "📥 Instalando kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        log_success "✅ kubectl instalado"
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "⚠️  jq no está instalado (información limitada)"
    fi
    
    # Verificar credenciales AWS
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "❌ Credenciales AWS no configuradas"
        return 1
    fi
    
    log_success "✅ Prerequisites verificados"
}

# Función principal
main() {
    echo "🏗️  CNN Chile - Monitor de Cluster EKS"
    echo "======================================"
    echo ""
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    monitor_cluster
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "🎉 ¡Cluster EKS listo para desplegar CNN Chile!"
    else
        echo ""
        log_error "💥 Error en la configuración del cluster"
        exit 1
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
