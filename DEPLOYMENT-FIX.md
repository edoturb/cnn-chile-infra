# 🚀 Solución Rápida para Problemas de Despliegue

## Resumen de Cambios

Este PR implementa una solución rápida para los problemas de despliegue de infraestructura AWS que estabas experimentando. Los principales cambios incluyen:

### ✅ Problemas Resueltos

1. **Certificados SSL sin validar** - Ahora puedes desplegar sin necesidad de validar certificados SSL
2. **Permisos IAM insuficientes** - Los recursos que requieren permisos complejos ahora son opcionales
3. **CloudFront bloqueado** - CloudFront es ahora completamente opcional
4. **MediaStore no disponible** - MediaStore es opcional para evitar errores de permisos
5. **Lambda@Edge fallando** - Funciones Lambda@Edge ahora son opcionales

### 🔧 Variables de Control Nuevas

Se han agregado las siguientes variables para controlar qué recursos se crean:

```hcl
enable_https           = false  # Deshabilita HTTPS y certificados SSL
enable_cloudfront      = false  # Deshabilita CloudFront
enable_mediastore      = false  # Deshabilita MediaStore
enable_lambda_edge     = false  # Deshabilita Lambda@Edge
enable_advanced_waf    = false  # Deshabilita WAF avanzado
enable_cognito_triggers = false  # Deshabilita triggers de Cognito
```

## 🚀 Despliegue Rápido (15-20 minutos)

### Opción 1: Usar configuración pre-configurada

```bash
cd terraform
cp terraform.tfvars.quick-deploy terraform.tfvars
terraform init
terraform plan
terraform apply
```

### Opción 2: Configuración manual

1. Crea un archivo `terraform/terraform.tfvars`:

```hcl
# Configuración básica
aws_region   = "us-east-1"
environment  = "dev"
project_name = "cnn-chile-dev"

# Deshabilitar características complejas
enable_https           = false
enable_cloudfront      = false
enable_mediastore      = false
enable_lambda_edge     = false
enable_advanced_waf    = false
enable_cognito_triggers = false
```

2. Ejecuta el despliegue:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 📊 Lo que se creará con la configuración rápida

### ✅ Recursos que se crean:

- **Networking**: VPC, subnets (públicas, privadas, de base de datos), NAT Gateway, Internet Gateway
- **Compute**: EKS Cluster (puede fallar si no hay permisos IAM suficientes)
- **Storage**: 
  - 3 buckets S3 (media, static, live-streaming)
  - 6 tablas DynamoDB (users, sessions, content, subscriptions, analytics, media_assets)
  - RDS PostgreSQL (puede fallar si no hay permisos)
- **Cache**: ElastiCache Redis (puede fallar si no hay permisos)
- **Load Balancer**: Application Load Balancer con HTTP (sin HTTPS)
- **Security**: 
  - Cognito User Pool (sin triggers Lambda)
  - WAF básico para API
  - Security Groups
- **Monitoring**: CloudWatch logs y métricas básicas
- **Messaging**: SNS topics, SQS queues

### ❌ Recursos que NO se crean (para evitar errores):

- CloudFront distributions (requieren certificados SSL validados)
- ACM certificates (requieren validación DNS)
- MediaStore containers (requieren permisos IAM especiales)
- Lambda@Edge functions (requieren CloudFront)
- Lambda triggers para Cognito (requieren permisos IAM)
- WAF avanzado para CloudFront (requiere CloudFront)

## 🔄 Migración a Producción

Cuando estés listo para producción y tengas:
- Certificados SSL validados
- Permisos IAM completos
- Dominio configurado

Puedes habilitar características adicionales gradualmente:

### Paso 1: Habilitar HTTPS

```hcl
enable_https = true
```

Esto creará certificados ACM que necesitarás validar vía DNS.

### Paso 2: Habilitar CloudFront

```hcl
enable_https      = true
enable_cloudfront = true
```

Esto creará distribuciones CloudFront una vez que los certificados estén validados.

### Paso 3: Habilitar todas las características

```hcl
enable_https           = true
enable_cloudfront      = true
enable_mediastore      = true
enable_lambda_edge     = true
enable_advanced_waf    = true
enable_cognito_triggers = true
```

## 🐛 Solucionar Problemas Comunes

### Error: Backend S3 no existe

Si ves un error sobre el backend S3:

```bash
cd terraform
terraform init -backend=false
```

Luego crea el bucket manualmente o configura un backend local:

```hcl
# Comenta el bloque backend en main.tf
# backend "s3" {
#   bucket = "cnn-chile-terraform-state-220017832616"
#   key    = "infrastructure/terraform.tfstate"
#   region = "us-east-1"
# }
```

### Error: Secretos programados para eliminación

```bash
# Listar secretos
aws secretsmanager list-secrets

# Recuperar secreto
aws secretsmanager restore-secret --secret-id <secret-id>

# O eliminar permanentemente
aws secretsmanager delete-secret --secret-id <secret-id> --force-delete-without-recovery
```

### Error: EKS cluster no se puede crear

Si no tienes permisos para crear roles IAM:
1. El despliegue fallará en EKS pero otros recursos se crearán correctamente
2. Puedes crear el EKS cluster manualmente en la consola de AWS
3. O usar roles IAM pre-existentes del Learner Lab

### Error: RDS no se puede crear

Similar al EKS, si falla:
1. Otros recursos se crearán correctamente
2. Puedes crear RDS manualmente si es necesario
3. O continuar sin RDS usando solo DynamoDB

## 📈 Recursos Mínimos Viables

Si necesitas el despliegue más rápido posible, estos son los recursos esenciales:

```hcl
# Solo infraestructura básica
# En este caso, considera comentar o deshabilitar:
# - EKS (si no tienes permisos IAM)
# - RDS (si no tienes permisos)
# - ElastiCache (si no tienes permisos)
```

Los recursos que siempre deberían funcionar:
- VPC y subnets
- S3 buckets
- DynamoDB tables
- Security Groups
- Cognito User Pool (sin triggers)
- ALB (sin HTTPS)

## 📝 Próximos Pasos

1. ✅ Ejecutar `terraform apply` con configuración rápida
2. ✅ Verificar qué recursos se crearon exitosamente
3. ⏸️ Abordar manualmente los recursos que fallaron (si es necesario)
4. ⏸️ Validar certificados SSL cuando estés listo para HTTPS
5. ⏸️ Habilitar CloudFront gradualmente
6. ⏸️ Configurar MediaStore si necesitas streaming en vivo

## 📚 Documentación Adicional

- [QUICK-DEPLOY-GUIDE.md](./QUICK-DEPLOY-GUIDE.md) - Guía detallada de despliegue
- [DEPLOYMENT-STATUS.md](./DEPLOYMENT-STATUS.md) - Estado actual del despliegue
- [README.md](./README.md) - Descripción general del proyecto

## 💡 Consideraciones de Seguridad

⚠️ **IMPORTANTE**: La configuración rápida usa HTTP sin encriptación. Esto está bien para:
- Desarrollo local
- Entornos de testing
- Pruebas de concepto

❌ **NO usar en producción** sin HTTPS habilitado.

Para producción, asegúrate de:
- ✅ Habilitar HTTPS (`enable_https = true`)
- ✅ Validar certificados SSL
- ✅ Habilitar WAF avanzado
- ✅ Revisar Security Groups
- ✅ Habilitar logging completo
