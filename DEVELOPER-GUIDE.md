# 🚀 CNN Chile - Guía de Despliegue y Configuración

## 📊 Estado de la Infraestructura

**✅ INFRAESTRUCTURA OPERATIVA - 77/125 recursos (61.6%)**

### 🎯 **Recursos Completamente Funcionales:**
- ✅ **Networking**: VPC multi-AZ completa
- ✅ **Storage**: 5 buckets S3 + 6 tablas DynamoDB
- ✅ **Security**: WAF, SSL, Security Groups
- ✅ **Load Balancer**: ALB activo
- ✅ **Messaging**: SNS + SQS operativo
- 🔄 **Cache**: ElastiCache Redis creándose

---

## 🔗 **Endpoints y URLs Importantes**

### **Application Load Balancer**
```
ALB DNS: cnn-chile-dev-alb-1352075639.us-east-1.elb.amazonaws.com
Estado: ✅ ACTIVO
Uso: APIs y backend services
```

### **S3 Buckets Operativos**
```
Static Content:   cnn-chile-dev-static-content-2854546c
Live Streaming:   cnn-chile-dev-live-streaming-2854546c
Media Content:    cnn-chile-dev-media-content-2854546c
Terraform State:  cnn-chile-terraform-state-220017832616

URL S3 Estático: https://cnn-chile-dev-static-content-2854546c.s3.amazonaws.com/index.html
```

### **DynamoDB Tables**
```
Users:          cnn-chile-dev-users
Content:        cnn-chile-dev-content  
Sessions:       cnn-chile-dev-sessions
Analytics:      cnn-chile-dev-analytics
Subscriptions:  cnn-chile-dev-subscriptions
Media Assets:   cnn-chile-dev-media-assets
```

### **VPC y Networking**
```
VPC ID:         vpc-025aea4b75e561b62
CIDR Block:     10.0.0.0/16

Subnets Públicas:
- subnet-0128b8e37a130d124 (10.0.1.0/24) us-east-1a
- subnet-00de36402d3319eea (10.0.2.0/24) us-east-1b  
- subnet-0fb1a850f2edc0688 (10.0.3.0/24) us-east-1c
```

---

## 🛠️ **Configuración para Desarrolladores**

### **1. Variables de Entorno**
```bash
# AWS Region
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1

# VPC Configuration
export VPC_ID=vpc-025aea4b75e561b62
export PUBLIC_SUBNET_1=subnet-0128b8e37a130d124
export PUBLIC_SUBNET_2=subnet-00de36402d3319eea
export PUBLIC_SUBNET_3=subnet-0fb1a850f2edc0688

# Application Load Balancer
export ALB_DNS=cnn-chile-dev-alb-1352075639.us-east-1.elb.amazonaws.com
export ALB_URL=http://${ALB_DNS}

# S3 Buckets
export STATIC_BUCKET=cnn-chile-dev-static-content-2854546c
export STREAMING_BUCKET=cnn-chile-dev-live-streaming-2854546c
export MEDIA_BUCKET=cnn-chile-dev-media-content-2854546c

# DynamoDB Tables
export USERS_TABLE=cnn-chile-dev-users
export CONTENT_TABLE=cnn-chile-dev-content
export SESSIONS_TABLE=cnn-chile-dev-sessions
export ANALYTICS_TABLE=cnn-chile-dev-analytics
```

### **2. Comandos Útiles AWS CLI**

#### **S3 Operations**
```bash
# Subir contenido estático
aws s3 sync ./frontend/build/ s3://${STATIC_BUCKET}/

# Ver contenido de buckets
aws s3 ls s3://${STATIC_BUCKET}/
aws s3 ls s3://${MEDIA_BUCKET}/

# Descargar archivos
aws s3 cp s3://${STATIC_BUCKET}/config.json ./
```

#### **DynamoDB Operations**
```bash
# Listar tablas
aws dynamodb list-tables

# Ver schema de tabla
aws dynamodb describe-table --table-name ${USERS_TABLE}

# Insertar item de prueba
aws dynamodb put-item --table-name ${USERS_TABLE} \
  --item '{"userId":{"S":"test-1"},"email":{"S":"test@cnn.cl"}}'

# Escanear tabla (cuidado en producción)
aws dynamodb scan --table-name ${USERS_TABLE} --limit 5
```

#### **Load Balancer Health Check**
```bash
# Test conectividad ALB
curl -I http://${ALB_DNS}/health

# Ver target groups
aws elbv2 describe-target-groups
```

---

## 🚀 **Opciones de Despliegue**

### **Opción 1: Frontend Estático en S3 (Actual)**
```bash
# 1. Build tu aplicación frontend
npm run build  # o yarn build

# 2. Subir a S3
aws s3 sync ./dist/ s3://${STATIC_BUCKET}/

# 3. Acceder
open https://${STATIC_BUCKET}.s3.amazonaws.com/index.html
```

### **Opción 2: APIs con ALB + EC2/Fargate**
```bash
# 1. Crear instancia EC2 en subnets públicas
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t3.micro \
  --subnet-id ${PUBLIC_SUBNET_1} \
  --security-group-ids sg-xxx

# 2. Configurar target group del ALB
aws elbv2 register-targets \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --targets Id=i-1234567890abcdef0
```

### **Opción 3: Configuración Manual de EKS**
```bash
# 1. Crear cluster EKS manualmente en la consola AWS
# 2. Usar las subnets existentes
# 3. Configurar kubectl
aws eks update-kubeconfig --region us-east-1 --name cnn-chile-dev

# 4. Desplegar aplicaciones
kubectl apply -f k8s-manifests/
```

---

## 📋 **Health Checks y Monitoreo**

### **Servicios Activos (Health Check Reciente)**
```
✅ AWS Connectivity: OK (Account: 220017832616)
✅ S3 Buckets: 5 buckets operativos
✅ CloudWatch Logs: /aws/application/cnn-chile
⚠️  EKS Cluster: No encontrado (esperado)
⚠️  RDS Database: No encontrado (esperado) 
🔄 ElastiCache: Creándose
```

### **Script de Monitoreo Automático**
```bash
# Ejecutar health check
cd /path/to/cnn-chile-infra
./scripts/health-check.sh

# Monitoreo continuo (cada 5 minutos)
watch -n 300 './scripts/health-check.sh'
```

---

## 💰 **Costos Estimados**

| Servicio | Costo Mensual Estimado |
|----------|------------------------|
| NAT Gateways (3x) | $32.85 |
| Application Load Balancer | $16.20 |
| ElastiCache Redis (t3.micro) | $15.00 |
| DynamoDB (bajo uso) | $5.00 |
| S3 Storage + Requests | $3.00 |
| CloudWatch Logs | $2.00 |
| **TOTAL** | **~$74.05/mes** |

---

## 🛡️ **Limitaciones Conocidas (AWS Learner Lab)**

### **Servicios NO Disponibles:**
- ❌ IAM Role Creation (roles personalizados)
- ❌ CloudFront Origin Access Control
- ❌ MediaStore Container
- ❌ X-Ray Tracing
- ❌ Secrets Manager (conflictos)

### **Workarounds Disponibles:**
- ✅ **En lugar de EKS**: Usar EC2 + Docker
- ✅ **En lugar de Lambda**: Usar Fargate tasks
- ✅ **En lugar de CloudFront**: Usar S3 directo o ALB
- ✅ **En lugar de Cognito**: Implementar auth custom

---

## 📞 **Próximos Pasos Recomendados**

### **Inmediatos (Hoy):**
1. ✅ Desplegar frontend en S3 (COMPLETADO)
2. 🔄 Esperar que termine Redis (en proceso)
3. 📊 Configurar APIs básicas con ALB

### **Corto Plazo (Esta Semana):**
1. 🖥️ Configurar EC2 instances para backend
2. 🔐 Implementar autenticación custom
3. 📱 Configurar APIs REST

### **Mediano Plazo (Próximo Mes):**
1. ⚡ Migrar a EKS cuando sea posible
2. 🎥 Configurar streaming con MediaStore alternativo
3. 🚀 Optimizar performance y costos

---

## 📧 **Soporte y Documentación**

**Documentos Clave:**
- `DETAILED-INFRASTRUCTURE-ANALYSIS.md` - Análisis completo
- `DEPLOYMENT-STATUS.md` - Estado actual
- `scripts/health-check.sh` - Monitoreo automatizado

**Contacto de Infraestructura:**
- Environment: dev
- Account: 220017832616
- Region: us-east-1
- Terraform State: S3 bucket `cnn-chile-terraform-state-220017832616`

---

*Generado automáticamente el 1 de diciembre de 2025*
