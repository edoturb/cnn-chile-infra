# Guía de Despliegue - CNN Chile Infrastructure

## Prerrequisitos

### Herramientas Requeridas
- AWS CLI v2.x configurado con credenciales apropiadas
- Terraform >= 1.0
- kubectl >= 1.24
- Docker >= 20.x
- Helm >= 3.x (opcional)

### Permisos AWS Requeridos
El usuario/rol de AWS debe tener permisos para:
- EC2, VPC, EKS, RDS, DynamoDB
- Lambda, API Gateway, CloudFront
- IAM, Secrets Manager, CloudWatch
- S3, MediaStore, WAF

### Variables de Entorno
```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=cnn-chile-production
export TF_VAR_environment=prod
export TF_VAR_project_name=cnn-chile
```

## Fase 1: Preparación del Entorno

### 1.1 Configurar Backend de Terraform

```bash
# Crear bucket para Terraform state
aws s3 mb s3://cnn-chile-terraform-state --region us-east-1

# Habilitar versioning
aws s3api put-bucket-versioning \
  --bucket cnn-chile-terraform-state \
  --versioning-configuration Status=Enabled

# Habilitar cifrado
aws s3api put-bucket-encryption \
  --bucket cnn-chile-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 1.2 Clonar y Preparar el Repositorio

```bash
git clone https://github.com/cnn-chile/cnn-chile-infra.git
cd cnn-chile-infra
```

### 1.3 Configurar Variables Sensibles

```bash
# Crear archivo terraform.tfvars
cat > terraform/terraform.tfvars << EOF
aws_region = "us-east-1"
environment = "prod"
project_name = "cnn-chile"

# OAuth Configuration
google_client_id = "your-google-client-id"
facebook_app_id = "your-facebook-app-id"

# Database Configuration
rds_instance_class = "db.r5.large"
rds_allocated_storage = 100

# EKS Configuration
eks_node_instance_types = ["t3.large", "t3.xlarge"]
eks_node_desired_capacity = 3
eks_node_max_capacity = 20
EOF
```

## Fase 2: Despliegue de Infraestructura

### 2.1 Inicializar Terraform

```bash
cd terraform
terraform init

# Verificar plan
terraform plan
```

### 2.2 Desplegar Infraestructura Base

```bash
# Desplegar en etapas para evitar timeouts
terraform apply -target=aws_vpc.main -target=aws_subnet.private -target=aws_subnet.public
terraform apply -target=aws_eks_cluster.main
terraform apply -target=aws_db_instance.main
terraform apply -auto-approve
```

**Tiempo estimado**: 20-30 minutos

### 2.3 Configurar kubectl

```bash
# Configurar acceso al cluster EKS
aws eks update-kubeconfig --region us-east-1 --name cnn-chile-cluster

# Verificar conectividad
kubectl get nodes
kubectl get namespaces
```

## Fase 3: Despliegue de Microservicios

### 3.1 Aplicar Configuraciones Base

```bash
cd ../kubernetes

# Crear namespaces
kubectl apply -f base/namespaces.yaml

# Aplicar secrets (actualizar con valores reales primero)
kubectl apply -f base/secrets.yaml

# Aplicar configmaps
kubectl apply -f base/configmaps.yaml
```

### 3.2 Desplegar Microservicios

```bash
# Desplegar servicios en orden
kubectl apply -f microservices/user-service.yaml
kubectl apply -f microservices/content-service.yaml
kubectl apply -f microservices/streaming-service.yaml
kubectl apply -f microservices/payment-service.yaml
kubectl apply -f microservices/api-gateway.yaml

# Verificar deployments
kubectl get pods -n cnn-chile
kubectl get services -n cnn-chile
```

### 3.3 Configurar Ingress

```bash
# Instalar NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Aplicar ingress rules
kubectl apply -f base/ingress.yaml
```

## Fase 4: Configuración de Dominios y Certificados

### 4.1 Configurar Route 53

```bash
# Obtener ALB DNS name
ALB_DNS=$(kubectl get ingress cnn-chile-ingress -n cnn-chile -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Crear registros DNS (reemplazar ZONE_ID)
aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "api.cnnchile.com",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "'$ALB_DNS'"}]
    }
  }]
}'
```

### 4.2 Validar Certificados SSL

```bash
# Verificar estado de certificados ACM
aws acm list-certificates --region us-east-1
aws acm describe-certificate --certificate-arn <cert-arn>
```

## Fase 5: Configuración de Bases de Datos

### 5.1 Configurar Schemas de PostgreSQL

```bash
# Conectar a RDS
DB_ENDPOINT=$(terraform output -raw rds_endpoint)
PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id cnn-chile-db-password --query SecretString --output text | jq -r .password)

psql -h $DB_ENDPOINT -U postgres -d cnnchile << EOF
-- Crear schemas principales
CREATE SCHEMA IF NOT EXISTS content;
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS billing;

-- Crear índices principales
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_content_published_at ON content.articles(published_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users.profiles(email);
EOF
```

### 5.2 Inicializar DynamoDB

```bash
# Scripts de inicialización están incluidos en los microservicios
# Se ejecutan automáticamente en el primer despliegue
kubectl logs -n cnn-chile -l app=user-service --tail=50
```

## Fase 6: Configuración de Servicios Externos

### 6.1 Configurar Stripe Webhooks

```bash
# Configurar webhook endpoint en Stripe Dashboard
WEBHOOK_URL="https://api.cnnchile.com/api/v1/payments/webhooks/stripe"

# El webhook secret debe configurarse en los secrets de Kubernetes
kubectl create secret generic stripe-webhook-secret \
  --from-literal=STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret \
  --namespace=cnn-chile
```

### 6.2 Configurar Notificaciones Push

```bash
# Configurar SNS topic para notificaciones push
aws sns create-platform-application \
  --name cnn-chile-android \
  --platform GCM \
  --attributes PlatformCredential=your-fcm-server-key

aws sns create-platform-application \
  --name cnn-chile-ios \
  --platform APNS \
  --attributes PlatformCredential=your-apns-certificate
```

## Fase 7: Configuración de Monitoreo

### 7.1 Configurar CloudWatch Dashboards

```bash
# Los dashboards se crean automáticamente con Terraform
# Verificar en AWS Console > CloudWatch > Dashboards
```

### 7.2 Configurar Alertas

```bash
# Configurar SNS topic para alertas
aws sns create-topic --name cnn-chile-alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT:cnn-chile-alerts \
  --protocol email \
  --notification-endpoint devops@cnnchile.com
```

## Fase 8: Testing y Validación

### 8.1 Health Checks

```bash
# Verificar health endpoints
curl -f https://api.cnnchile.com/health
curl -f https://api.cnnchile.com/api/v1/users/health
curl -f https://api.cnnchile.com/api/v1/content/health
```

### 8.2 Load Testing (Opcional)

```bash
# Usar k6 o similar para load testing
k6 run --vus 100 --duration 5m scripts/load-test.js
```

### 8.3 Security Scan

```bash
# Ejecutar OWASP ZAP o similar
docker run -t owasp/zap2docker-stable zap-baseline.py -t https://api.cnnchile.com
```

## Fase 9: Go-Live Checklist

### Pre-Launch
- [ ] Todos los health checks pasan
- [ ] Certificados SSL válidos y configurados
- [ ] Dominios DNS configurados correctamente
- [ ] Backups de base de datos configurados
- [ ] Monitoreo y alertas funcionando
- [ ] Secrets y variables de entorno configuradas
- [ ] Load balancer y auto-scaling configurados
- [ ] CDN cache configurado y funcionando

### Post-Launch
- [ ] Monitorear métricas por 24-48 horas
- [ ] Verificar logs de aplicación por errores
- [ ] Confirmar que los backups se ejecutan correctamente
- [ ] Validar facturación y costos de AWS
- [ ] Documentar cualquier ajuste post-despliegue

## Comandos de Troubleshooting

### Logs de Aplicación
```bash
# Ver logs de microservicios
kubectl logs -n cnn-chile -l app=user-service --tail=100 -f
kubectl logs -n cnn-chile -l app=content-service --tail=100 -f

# Ver logs de ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 -f
```

### Debugging de Base de Datos
```bash
# Conectividad a RDS
kubectl run -it --rm --image=postgres:13 -- psql -h $DB_ENDPOINT -U postgres

# Verificar DynamoDB
aws dynamodb scan --table-name cnn-chile-users --limit 5
```

### Monitoreo de Performance
```bash
# Top pods por uso de recursos
kubectl top pods -n cnn-chile

# Eventos del cluster
kubectl get events -n cnn-chile --sort-by=.metadata.creationTimestamp
```

## Rollback Procedures

### Rollback de Kubernetes
```bash
# Rollback de deployment
kubectl rollout undo deployment/user-service -n cnn-chile
kubectl rollout status deployment/user-service -n cnn-chile
```

### Rollback de Terraform
```bash
# Usar state backup
terraform apply -auto-approve -backup=terraform.tfstate.backup
```

### Rollback de Base de Datos
```bash
# Restaurar desde backup automático (RDS)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier cnn-chile-database-restored \
  --db-snapshot-identifier cnn-chile-database-snapshot-YYYY-MM-DD
```

## Contactos y Soporte

- **DevOps Team**: devops@cnnchile.com
- **Security Team**: security@cnnchile.com
- **On-Call**: +56 9 XXXX XXXX

## Referencias

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [OWASP Security Guidelines](https://owasp.org/)
