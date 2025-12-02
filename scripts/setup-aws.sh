#!/bin/bash

# 🔧 Script de Configuración AWS CLI - CNN Chile Infrastructure
# Configuración automatizada para pruebas

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

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

log_section() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

# Función para mostrar opciones de configuración
show_setup_options() {
    log_section "Opciones de Configuración AWS CLI"
    
    echo -e "${CYAN}Selecciona el método de configuración:${NC}"
    echo ""
    echo "1. 🔑 Credenciales IAM User (Access Key + Secret)"
    echo "2. 🎫 AWS SSO (Single Sign-On)"
    echo "3. 👤 Perfil existente"
    echo "4. 🔄 Renovar token existente"
    echo "5. ❓ Mostrar ayuda"
    echo ""
}

# Configuración IAM User
setup_iam_user() {
    log_section "Configuración con IAM User"
    
    echo -e "${YELLOW}Necesitarás:${NC}"
    echo "- Access Key ID"
    echo "- Secret Access Key"
    echo "- Región (recomendado: us-east-1)"
    echo ""
    
    log_info "Ejecuta el siguiente comando y sigue las instrucciones:"
    echo -e "${CYAN}aws configure${NC}"
    echo ""
    echo "Valores recomendados:"
    echo "- Default region name: us-east-1"
    echo "- Default output format: json"
}

# Configuración AWS SSO
setup_aws_sso() {
    log_section "Configuración con AWS SSO"
    
    echo -e "${YELLOW}Para configurar AWS SSO:${NC}"
    echo ""
    echo "1. Configura SSO:"
    echo -e "   ${CYAN}aws configure sso${NC}"
    echo ""
    echo "2. Necesitarás:"
    echo "   - SSO start URL de tu organización"
    echo "   - Región SSO (ej: us-east-1)"
    echo "   - Nombre del perfil (ej: cnn-chile)"
    echo ""
    echo "3. Después de configurar, usa:"
    echo -e "   ${CYAN}aws sso login --profile cnn-chile${NC}"
}

# Configurar perfil existente
setup_existing_profile() {
    log_section "Usar Perfil Existente"
    
    log_info "Perfiles disponibles:"
    aws configure list-profiles 2>/dev/null || echo "No hay perfiles configurados"
    echo ""
    
    echo "Para usar un perfil específico:"
    echo -e "${CYAN}export AWS_PROFILE=nombre-del-perfil${NC}"
    echo ""
    echo "O para hacer login con SSO:"
    echo -e "${CYAN}aws sso login --profile nombre-del-perfil${NC}"
}

# Renovar token
refresh_token() {
    log_section "Renovando Token AWS"
    
    log_info "Intentando renovar credenciales..."
    
    # Verificar si hay perfil SSO configurado
    if aws configure list-profiles | grep -q "sso"; then
        log_info "Detectado perfil SSO, intentando login..."
        
        # Obtener el primer perfil que parece SSO
        local sso_profile=$(aws configure list-profiles | head -n1)
        
        echo "¿Deseas hacer login con el perfil '$sso_profile'? (y/n)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            aws sso login --profile "$sso_profile"
            export AWS_PROFILE="$sso_profile"
            log_success "Profile configurado: $sso_profile"
        fi
    else
        log_warning "No se detectaron perfiles SSO"
        log_info "Puedes renovar manualmente con:"
        echo -e "${CYAN}aws configure${NC}"
    fi
}

# Verificar configuración
verify_aws_config() {
    log_section "Verificando Configuración AWS"
    
    log_info "Verificando credenciales..."
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        log_success "✅ Credenciales válidas"
        
        local identity=$(aws sts get-caller-identity)
        local account=$(echo "$identity" | jq -r '.Account' 2>/dev/null || echo "N/A")
        local user=$(echo "$identity" | jq -r '.Arn' 2>/dev/null || echo "N/A")
        
        echo ""
        echo -e "${GREEN}Información de la cuenta:${NC}"
        echo "- Account ID: $account"
        echo "- User/Role: $user"
        
        # Verificar región
        local region=$(aws configure get region)
        echo "- Región: ${region:-"No configurada"}"
        
        # Verificar permisos básicos
        log_info "Verificando permisos básicos..."
        
        if aws ec2 describe-regions --region us-east-1 >/dev/null 2>&1; then
            log_success "✅ Permisos EC2: OK"
        else
            log_warning "⚠️ Permisos EC2: Limitados"
        fi
        
        if aws iam get-user >/dev/null 2>&1; then
            log_success "✅ Permisos IAM: OK"
        else
            log_warning "⚠️ Permisos IAM: Limitados"
        fi
        
        return 0
    else
        log_error "❌ Credenciales inválidas o expiradas"
        return 1
    fi
}

# Configurar variables de entorno
setup_environment() {
    log_section "Configurando Variables de Entorno"
    
    # Archivo de configuración local
    local env_file=".env.aws"
    
    cat > "$env_file" << EOF
# Configuración AWS para CNN Chile Infrastructure
# Generado automáticamente el $(date)

# Región por defecto
export AWS_DEFAULT_REGION=us-east-1
export AWS_REGION=us-east-1

# Perfil (descomenta si usas perfil específico)
# export AWS_PROFILE=cnn-chile

# Para Terraform
export TF_VAR_region=us-east-1
export TF_VAR_environment=dev

# Para pruebas
export ENVIRONMENT=dev
export BASE_URL=https://dev.cnnchile.com
EOF

    log_success "Variables de entorno guardadas en: $env_file"
    
    echo ""
    echo -e "${YELLOW}Para usar estas variables:${NC}"
    echo -e "${CYAN}source $env_file${NC}"
}

# Ejecutar prueba de conexión
test_aws_connection() {
    log_section "Probando Conexión AWS"
    
    if verify_aws_config; then
        log_info "Ejecutando pruebas básicas de conectividad..."
        
        # Test 1: Listar regiones
        log_info "Test 1: Listando regiones disponibles..."
        if aws ec2 describe-regions --query 'Regions[0:3].{Name:RegionName}' --output table; then
            log_success "✅ Conectividad EC2: OK"
        fi
        
        # Test 2: Verificar S3 (si tiene permisos)
        log_info "Test 2: Verificando acceso S3..."
        if aws s3 ls >/dev/null 2>&1; then
            log_success "✅ Acceso S3: OK"
        else
            log_warning "⚠️ Acceso S3: Limitado o no configurado"
        fi
        
        log_success "🎉 AWS CLI configurado y funcionando correctamente!"
        
        echo ""
        echo -e "${GREEN}¿Listo para ejecutar las pruebas completas?${NC}"
        echo -e "${CYAN}./scripts/run-tests.sh --all-tests${NC}"
        
        return 0
    else
        log_error "Configuración no válida. Por favor, configura AWS CLI primero."
        return 1
    fi
}

# Función principal
main() {
    echo -e "${PURPLE}"
    echo "🔧 =============================================="
    echo "   CONFIGURACIÓN AWS CLI - CNN CHILE"
    echo "   Setup automático para pruebas de infraestructura"
    echo "===============================================${NC}"
    
    # Verificar si ya está configurado
    if verify_aws_config 2>/dev/null; then
        log_success "AWS CLI ya está configurado y funcionando!"
        echo ""
        echo "¿Deseas ejecutar las pruebas ahora? (y/n)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log_info "Ejecutando suite de pruebas..."
            ./run-tests.sh --all-tests
            return 0
        else
            log_info "Configuración completa. Ejecuta './run-tests.sh --all-tests' cuando estés listo."
            return 0
        fi
    fi
    
    # Mostrar opciones si no está configurado
    while true; do
        show_setup_options
        
        echo -n "Selecciona una opción [1-5]: "
        read -r choice
        
        case $choice in
            1)
                setup_iam_user
                echo ""
                echo "Después de configurar, presiona Enter para continuar..."
                read -r
                verify_aws_config && setup_environment && test_aws_connection
                break
                ;;
            2)
                setup_aws_sso
                echo ""
                echo "Después de configurar SSO, presiona Enter para continuar..."
                read -r
                verify_aws_config && setup_environment && test_aws_connection
                break
                ;;
            3)
                setup_existing_profile
                echo ""
                echo "Después de configurar el perfil, presiona Enter para continuar..."
                read -r
                verify_aws_config && setup_environment && test_aws_connection
                break
                ;;
            4)
                refresh_token
                verify_aws_config && setup_environment && test_aws_connection
                break
                ;;
            5)
                echo ""
                echo -e "${CYAN}Documentación útil:${NC}"
                echo "- AWS CLI Configuration: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html"
                echo "- AWS SSO: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html"
                echo "- CNN Chile Infrastructure Docs: ./docs/"
                echo ""
                ;;
            *)
                log_error "Opción inválida. Por favor selecciona 1-5."
                ;;
        esac
    done
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
