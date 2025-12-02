#!/bin/bash

# 🧪 Script de Pruebas Completas - CNN Chile Infrastructure
# Autor: CNN Chile DevOps Team
# Versión: 1.0.0

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Configuración
ENVIRONMENT=${ENVIRONMENT:-"dev"}
RUN_UNIT_TESTS=${RUN_UNIT_TESTS:-"true"}
RUN_INTEGRATION_TESTS=${RUN_INTEGRATION_TESTS:-"true"}
RUN_E2E_TESTS=${RUN_E2E_TESTS:-"false"}
RUN_LOAD_TESTS=${RUN_LOAD_TESTS:-"false"}
RUN_SECURITY_TESTS=${RUN_SECURITY_TESTS:-"true"}
PARALLEL_EXECUTION=${PARALLEL_EXECUTION:-"true"}

# Funciones de utilidad
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

# Crear directorio de resultados
create_test_results_dir() {
    mkdir -p "$TEST_RESULTS_DIR"
    log_info "Directorio de resultados creado: $TEST_RESULTS_DIR"
}

# Verificar prerrequisitos
check_prerequisites() {
    log_section "Verificando Prerrequisitos"
    
    local missing_tools=()
    
    # Herramientas requeridas
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v node >/dev/null 2>&1 || missing_tools+=("nodejs")
    command -v npm >/dev/null 2>&1 || missing_tools+=("npm")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Herramientas faltantes: ${missing_tools[*]}"
        log_info "Instala las herramientas faltantes antes de continuar"
        exit 1
    fi
    
    # Verificar versiones
    log_info "AWS CLI: $(aws --version)"
    log_info "Terraform: $(terraform --version | head -n1)"
    log_info "kubectl: $(kubectl version --client --short)"
    log_info "Docker: $(docker --version)"
    log_info "Node.js: $(node --version)"
    log_info "npm: $(npm --version)"
    
    log_success "Todos los prerrequisitos están instalados"
}

# Verificar credenciales AWS
check_aws_credentials() {
    log_section "Verificando Credenciales AWS"
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "Credenciales AWS no configuradas o inválidas"
        log_info "Ejecuta: aws configure"
        exit 1
    fi
    
    local caller_identity=$(aws sts get-caller-identity)
    local account_id=$(echo "$caller_identity" | jq -r '.Account')
    local user_arn=$(echo "$caller_identity" | jq -r '.Arn')
    
    log_info "Cuenta AWS: $account_id"
    log_info "Usuario/Role: $user_arn"
    log_success "Credenciales AWS válidas"
}

# Validar Terraform
validate_terraform() {
    log_section "Validando Terraform"
    
    cd "$PROJECT_ROOT/terraform"
    
    # Formatear código
    log_info "Formateando código Terraform..."
    terraform fmt -check || {
        log_warning "Código no está formateado, aplicando formato..."
        terraform fmt
    }
    
    # Inicializar backend (si es necesario)
    if [ ! -d ".terraform" ]; then
        log_info "Inicializando Terraform..."
        terraform init -backend=false
    fi
    
    # Validar configuración
    log_info "Validando configuración Terraform..."
    terraform validate
    
    # Plan (dry-run)
    log_info "Ejecutando terraform plan..."
    terraform plan \
        -var-file="environments/${ENVIRONMENT}.tfvars" \
        -out="$TEST_RESULTS_DIR/terraform-plan-${TIMESTAMP}.tfplan" \
        > "$TEST_RESULTS_DIR/terraform-plan-${TIMESTAMP}.log" 2>&1
    
    log_success "Terraform validado correctamente"
    cd "$PROJECT_ROOT"
}

# Validar Kubernetes
validate_kubernetes() {
    log_section "Validando Kubernetes"
    
    cd "$PROJECT_ROOT/kubernetes"
    
    # Validar manifiestos base
    log_info "Validando manifiestos base..."
    kubectl apply --dry-run=client -f base/ > "$TEST_RESULTS_DIR/k8s-base-validation.log" 2>&1
    
    # Validar microservicios
    log_info "Validando manifiestos de microservicios..."
    kubectl apply --dry-run=client -f microservices/ > "$TEST_RESULTS_DIR/k8s-microservices-validation.log" 2>&1
    
    log_success "Manifiestos Kubernetes válidos"
    cd "$PROJECT_ROOT"
}

# Pruebas unitarias
run_unit_tests() {
    if [ "$RUN_UNIT_TESTS" != "true" ]; then
        return 0
    fi
    
    log_section "Ejecutando Pruebas Unitarias"
    
    local test_dirs=(
        "microservices/content-management-api"
        "microservices/user-management-api"
        "microservices/subscription-api"
        "microservices/notification-api"
        "microservices/analytics-api"
        "lambda/notification-service"
        "lambda/event-processor"
    )
    
    for dir in "${test_dirs[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            log_info "Ejecutando tests en $dir..."
            
            cd "$PROJECT_ROOT/$dir"
            
            # Instalar dependencias si es necesario
            if [ -f "package.json" ] && [ ! -d "node_modules" ]; then
                npm ci
            fi
            
            # Ejecutar tests
            npm test -- --coverage --reporter=json \
                > "$TEST_RESULTS_DIR/$(basename "$dir")-unit-tests.json" 2>&1 || {
                log_error "Tests fallaron en $dir"
                return 1
            }
            
            log_success "Tests completados en $dir"
        fi
    done
    
    cd "$PROJECT_ROOT"
}

# Pruebas de integración
run_integration_tests() {
    if [ "$RUN_INTEGRATION_TESTS" != "true" ]; then
        return 0
    fi
    
    log_section "Ejecutando Pruebas de Integración"
    
    # Docker Compose para tests
    if [ -f "docker-compose.test.yml" ]; then
        log_info "Iniciando servicios de test con Docker Compose..."
        docker-compose -f docker-compose.test.yml up -d
        
        # Esperar que los servicios estén listos
        sleep 30
        
        # Ejecutar tests de integración
        log_info "Ejecutando tests de integración..."
        docker-compose -f docker-compose.test.yml exec api npm run test:integration \
            > "$TEST_RESULTS_DIR/integration-tests.log" 2>&1 || {
            log_error "Tests de integración fallaron"
            docker-compose -f docker-compose.test.yml down
            return 1
        }
        
        # Limpiar
        docker-compose -f docker-compose.test.yml down
        log_success "Tests de integración completados"
    else
        log_warning "docker-compose.test.yml no encontrado, saltando tests de integración"
    fi
}

# Pruebas de seguridad
run_security_tests() {
    if [ "$RUN_SECURITY_TESTS" != "true" ]; then
        return 0
    fi
    
    log_section "Ejecutando Pruebas de Seguridad"
    
    # Audit de dependencias
    log_info "Auditando dependencias de Node.js..."
    find "$PROJECT_ROOT" -name "package.json" -not -path "*/node_modules/*" | while read -r package_file; do
        dir=$(dirname "$package_file")
        cd "$dir"
        npm audit --audit-level moderate --json > "$TEST_RESULTS_DIR/$(basename "$dir")-audit.json" 2>&1 || {
            log_warning "Vulnerabilidades encontradas en $(basename "$dir")"
        }
    done
    
    # Escaneo de imágenes Docker (si existen)
    log_info "Escaneando imágenes Docker..."
    if command -v trivy >/dev/null 2>&1; then
        for dockerfile in $(find "$PROJECT_ROOT" -name "Dockerfile"); do
            image_name=$(basename "$(dirname "$dockerfile")")
            trivy fs --format json --output "$TEST_RESULTS_DIR/${image_name}-docker-scan.json" "$(dirname "$dockerfile")" || {
                log_warning "Scan falló para $image_name"
            }
        done
    else
        log_warning "Trivy no instalado, saltando escaneo de Docker"
    fi
    
    log_success "Pruebas de seguridad completadas"
    cd "$PROJECT_ROOT"
}

# Pruebas E2E
run_e2e_tests() {
    if [ "$RUN_E2E_TESTS" != "true" ]; then
        return 0
    fi
    
    log_section "Ejecutando Pruebas End-to-End"
    
    if [ -d "$PROJECT_ROOT/tests/e2e" ]; then
        cd "$PROJECT_ROOT/tests/e2e"
        
        # Playwright tests
        if [ -f "playwright.config.js" ]; then
            log_info "Ejecutando tests Playwright..."
            npx playwright test --reporter=json > "$TEST_RESULTS_DIR/playwright-results.json" 2>&1 || {
                log_error "Tests Playwright fallaron"
                return 1
            }
        fi
        
        # Cypress tests
        if [ -f "cypress.config.js" ]; then
            log_info "Ejecutando tests Cypress..."
            npx cypress run --reporter json > "$TEST_RESULTS_DIR/cypress-results.json" 2>&1 || {
                log_error "Tests Cypress fallaron"
                return 1
            }
        fi
        
        log_success "Pruebas E2E completadas"
    else
        log_warning "Directorio tests/e2e no encontrado"
    fi
    
    cd "$PROJECT_ROOT"
}

# Pruebas de carga
run_load_tests() {
    if [ "$RUN_LOAD_TESTS" != "true" ]; then
        return 0
    fi
    
    log_section "Ejecutando Pruebas de Carga"
    
    if command -v artillery >/dev/null 2>&1; then
        if [ -f "$PROJECT_ROOT/tests/load/api-load-test.yml" ]; then
            log_info "Ejecutando pruebas de carga de API..."
            artillery run "$PROJECT_ROOT/tests/load/api-load-test.yml" \
                --output "$TEST_RESULTS_DIR/load-test-api.json"
        fi
        
        if [ -f "$PROJECT_ROOT/tests/load/website-load-test.yml" ]; then
            log_info "Ejecutando pruebas de carga de website..."
            artillery run "$PROJECT_ROOT/tests/load/website-load-test.yml" \
                --output "$TEST_RESULTS_DIR/load-test-website.json"
        fi
        
        log_success "Pruebas de carga completadas"
    else
        log_warning "Artillery no instalado, saltando pruebas de carga"
        log_info "Instalar con: npm install -g artillery"
    fi
}

# Generar reporte
generate_report() {
    log_section "Generando Reporte de Pruebas"
    
    local report_file="$TEST_RESULTS_DIR/test-report-${TIMESTAMP}.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Pruebas - CNN Chile Infrastructure</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .header { text-align: center; margin-bottom: 30px; }
        .section { margin-bottom: 25px; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { background-color: #d4edda; border-color: #c3e6cb; }
        .warning { background-color: #fff3cd; border-color: #ffeaa7; }
        .error { background-color: #f8d7da; border-color: #f5c6cb; }
        .info { background-color: #d1ecf1; border-color: #bee5eb; }
        h1 { color: #c41e3a; }
        h2 { color: #333; border-bottom: 2px solid #c41e3a; padding-bottom: 5px; }
        .timestamp { color: #666; font-size: 0.9em; }
        .file-list { list-style-type: none; padding: 0; }
        .file-list li { padding: 5px 0; border-bottom: 1px dotted #ccc; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 Reporte de Pruebas</h1>
            <h2>CNN Chile Infrastructure</h2>
            <p class="timestamp">Ejecutado el: $(date)</p>
        </div>

        <div class="section info">
            <h2>📊 Resumen de Ejecución</h2>
            <p><strong>Entorno:</strong> $ENVIRONMENT</p>
            <p><strong>Timestamp:</strong> $TIMESTAMP</p>
            <p><strong>Directorio de resultados:</strong> $TEST_RESULTS_DIR</p>
        </div>

        <div class="section">
            <h2>📁 Archivos de Resultados</h2>
            <ul class="file-list">
EOF

    # Listar archivos de resultados
    if [ -d "$TEST_RESULTS_DIR" ]; then
        find "$TEST_RESULTS_DIR" -type f -name "*${TIMESTAMP}*" | while read -r file; do
            echo "                <li>$(basename "$file")</li>" >> "$report_file"
        done
    fi

    cat >> "$report_file" << EOF
            </ul>
        </div>

        <div class="section success">
            <h2>✅ Siguiente Pasos</h2>
            <ul>
                <li>Revisar los archivos de log para detalles específicos</li>
                <li>Corregir cualquier issue encontrado</li>
                <li>Re-ejecutar las pruebas si es necesario</li>
                <li>Proceder con el despliegue si todas las pruebas pasan</li>
            </ul>
        </div>

        <div class="section info">
            <h2>🔧 Comandos Útiles</h2>
            <pre>
# Ver logs detallados
cat $TEST_RESULTS_DIR/*.log

# Re-ejecutar pruebas específicas
$0 --unit-tests-only
$0 --integration-tests-only
$0 --security-tests-only

# Limpiar resultados anteriores
rm -rf $TEST_RESULTS_DIR/*
            </pre>
        </div>
    </div>
</body>
</html>
EOF

    log_success "Reporte generado: $report_file"
}

# Función principal
main() {
    log_info "🚀 Iniciando suite de pruebas CNN Chile Infrastructure"
    
    # Crear directorio de resultados
    create_test_results_dir
    
    # Verificaciones iniciales
    check_prerequisites
    check_aws_credentials
    
    # Validaciones de infraestructura
    validate_terraform
    validate_kubernetes
    
    # Ejecutar pruebas
    run_unit_tests
    run_integration_tests
    run_security_tests
    run_e2e_tests
    run_load_tests
    
    # Generar reporte
    generate_report
    
    log_success "✅ Suite de pruebas completada exitosamente!"
    log_info "📊 Revisa los resultados en: $TEST_RESULTS_DIR"
}

# Manejo de argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --unit-tests-only)
            RUN_UNIT_TESTS="true"
            RUN_INTEGRATION_TESTS="false"
            RUN_E2E_TESTS="false"
            RUN_LOAD_TESTS="false"
            RUN_SECURITY_TESTS="false"
            shift
            ;;
        --integration-tests-only)
            RUN_UNIT_TESTS="false"
            RUN_INTEGRATION_TESTS="true"
            RUN_E2E_TESTS="false"
            RUN_LOAD_TESTS="false"
            RUN_SECURITY_TESTS="false"
            shift
            ;;
        --security-tests-only)
            RUN_UNIT_TESTS="false"
            RUN_INTEGRATION_TESTS="false"
            RUN_E2E_TESTS="false"
            RUN_LOAD_TESTS="false"
            RUN_SECURITY_TESTS="true"
            shift
            ;;
        --e2e-tests-only)
            RUN_UNIT_TESTS="false"
            RUN_INTEGRATION_TESTS="false"
            RUN_E2E_TESTS="true"
            RUN_LOAD_TESTS="false"
            RUN_SECURITY_TESTS="false"
            shift
            ;;
        --load-tests-only)
            RUN_UNIT_TESTS="false"
            RUN_INTEGRATION_TESTS="false"
            RUN_E2E_TESTS="false"
            RUN_LOAD_TESTS="true"
            RUN_SECURITY_TESTS="false"
            shift
            ;;
        --all-tests)
            RUN_UNIT_TESTS="true"
            RUN_INTEGRATION_TESTS="true"
            RUN_E2E_TESTS="true"
            RUN_LOAD_TESTS="true"
            RUN_SECURITY_TESTS="true"
            shift
            ;;
        --help)
            echo "Uso: $0 [opciones]"
            echo "Opciones:"
            echo "  --environment ENV          Entorno a usar (dev/staging/prod)"
            echo "  --unit-tests-only          Solo ejecutar pruebas unitarias"
            echo "  --integration-tests-only   Solo ejecutar pruebas de integración"
            echo "  --security-tests-only      Solo ejecutar pruebas de seguridad"
            echo "  --e2e-tests-only          Solo ejecutar pruebas E2E"
            echo "  --load-tests-only         Solo ejecutar pruebas de carga"
            echo "  --all-tests               Ejecutar todas las pruebas"
            echo "  --help                    Mostrar esta ayuda"
            exit 0
            ;;
        *)
            log_error "Opción desconocida: $1"
            exit 1
            ;;
    esac
done

# Ejecutar función principal
main
