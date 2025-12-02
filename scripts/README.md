# Scripts de Despliegue Automatizado

Este directorio contiene scripts para la automatización completa del despliegue y gestión de la infraestructura de CNN Chile.

## Scripts Disponibles

### 1. `deploy.sh` - Script de Despliegue Principal

Script automatizado para el despliegue completo de la infraestructura CNN Chile.

**Uso:**
```bash
./scripts/deploy.sh [OPTIONS]
```

**Opciones:**
- `--skip-infrastructure`: Omite el despliegue de la infraestructura Terraform
- `--skip-kubernetes`: Omite el despliegue de Kubernetes
- `--help, -h`: Muestra ayuda

**Características:**
- Validación de prerrequisitos
- Configuración automática del backend de Terraform
- Despliegue por etapas para evitar timeouts
- Configuración automática de kubectl
- Configuración de secretos desde AWS Secrets Manager
- Instalación automática de NGINX Ingress Controller
- Validación post-despliegue

**Ejemplo:**
```bash
# Despliegue completo
./scripts/deploy.sh

# Solo despliegue de Kubernetes (infraestructura ya existe)
./scripts/deploy.sh --skip-infrastructure
```

### 2. `destroy.sh` - Script de Destrucción

Script para la destrucción segura de toda la infraestructura.

**Uso:**
```bash
./scripts/destroy.sh [OPTIONS]
```

**Opciones:**
- `--skip-backup`: Omite el respaldo de datos antes de la destrucción
- `--force`: Omite las confirmaciones de seguridad
- `--help, -h`: Muestra ayuda

**Características:**
- Respaldo automático de datos críticos
- Confirmaciones de seguridad múltiples
- Vaciado de buckets S3 antes de la destrucción
- Escalado a cero de recursos de Kubernetes
- Destrucción ordenada por dependencias
- Verificación post-destrucción

**Ejemplo:**
```bash
# Destrucción con respaldo
./scripts/destroy.sh

# Destrucción forzada sin respaldo
./scripts/destroy.sh --force --skip-backup
```

### 3. `health-check.sh` - Script de Monitoreo de Salud

Script comprehensivo para verificar el estado de toda la infraestructura.

**Uso:**
```bash
./scripts/health-check.sh [OPTIONS]
```

**Opciones:**
- `--endpoints`: Incluye verificación de endpoints de aplicación
- `--verbose`: Habilita salida detallada
- `--help, -h`: Muestra ayuda

**Verificaciones Incluidas:**
- Conectividad AWS
- Estado del cluster EKS
- Salud de pods y servicios
- Estado de bases de datos (RDS, DynamoDB, Redis)
- Funciones Lambda
- Distribuciones CloudFront
- Buckets S3
- Configuración de monitoreo

**Ejemplo:**
```bash
# Verificación básica
./scripts/health-check.sh

# Verificación completa con endpoints
./scripts/health-check.sh --endpoints --verbose
```

## Estructura de Logs

Los scripts generan logs estructurados con códigos de color:
- 🔵 **INFO**: Información general
- 🟡 **WARN**: Advertencias no críticas
- 🔴 **ERROR**: Errores que requieren atención
- 🟢 **SUCCESS**: Operaciones exitosas

## Variables de Entorno

### Variables Requeridas
```bash
export AWS_REGION="us-east-1"
export AWS_PROFILE="cnn-chile-production"
```

### Variables Opcionales
```bash
export TF_VAR_environment="prod"
export TF_VAR_project_name="cnn-chile"
export KUBECONFIG="~/.kube/config"
```

## Flujo de Despliegue Recomendado

### 1. Preparación
```bash
# Configurar AWS CLI
aws configure --profile cnn-chile-production

# Exportar variables
export AWS_PROFILE=cnn-chile-production
export AWS_REGION=us-east-1
```

### 2. Despliegue Inicial
```bash
# Clonar repositorio
git clone <repository-url>
cd cnn-chile-infra

# Ejecutar despliegue
./scripts/deploy.sh
```

### 3. Verificación
```bash
# Verificar estado del sistema
./scripts/health-check.sh --endpoints

# Verificar logs de aplicación
kubectl logs -n cnn-chile -l app=api-gateway --tail=50
```

### 4. Configuración Post-Despliegue
- Configurar registros DNS
- Actualizar certificados SSL
- Configurar integraciones externas (Stripe, OAuth)

## Troubleshooting

### Errores Comunes

#### Error: "EKS cluster not accessible"
```bash
# Reconfigurar kubectl
aws eks update-kubeconfig --region us-east-1 --name cnn-chile-cluster

# Verificar conectividad
kubectl get nodes
```

#### Error: "Terraform state locked"
```bash
# Forzar desbloqueo (usar con precaución)
terraform force-unlock <LOCK_ID>
```

#### Error: "S3 bucket not empty"
```bash
# Vaciar bucket manualmente
aws s3 rm s3://bucket-name --recursive
```

### Logs de Debug

Para debugging avanzado:
```bash
# Habilitar debug de Terraform
export TF_LOG=DEBUG

# Habilitar debug de kubectl
kubectl get pods -v=6

# Ver logs detallados de AWS CLI
aws --debug sts get-caller-identity
```

## Seguridad y Mejores Prácticas

### Secrets Management
- Nunca hardcodear credenciales en scripts
- Usar AWS Secrets Manager para datos sensibles
- Rotar credenciales regularmente

### Backup Strategy
- Respaldos automáticos antes de destrucción
- Snapshots de RDS programados
- Versionado de objetos S3 habilitado

### Access Control
- Usar IAM roles con permisos mínimos
- Habilitar MFA para operaciones críticas
- Auditar accesos regularmente

## Integración CI/CD

### GitHub Actions
```yaml
name: Deploy CNN Chile Infrastructure
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy Infrastructure
        run: ./scripts/deploy.sh --skip-infrastructure
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### GitLab CI
```yaml
deploy:
  stage: deploy
  script:
    - ./scripts/deploy.sh
  only:
    - main
  environment:
    name: production
```

## Mantenimiento

### Actualizaciones Regulares
```bash
# Actualizar versiones de Kubernetes
kubectl version --client

# Actualizar AMI de nodos EKS
terraform plan -target=aws_launch_template.eks_nodes

# Actualizar funciones Lambda
cd lambda/notification-service
npm update
```

### Monitoreo Continuo
```bash
# Ejecutar health checks automáticamente
crontab -e
# Agregar: */5 * * * * /path/to/health-check.sh
```

## Contacto y Soporte

Para issues o preguntas sobre los scripts:
- **DevOps Team**: devops@cnnchile.com
- **Repository Issues**: GitHub Issues
- **Documentation**: /docs/deployment-guide.md
