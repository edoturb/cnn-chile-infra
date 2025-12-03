# Estado Actual del Despliegue

## Recursos Creados Exitosamente ✅

### Red y Conectividad
- VPC principal
- 3 subnets públicas, privadas y de base de datos
- Internet Gateway y NAT Gateways
- Route tables y asociaciones
- Elastic IPs

### Almacenamiento
- 3 buckets S3 (live streaming, media content, static content)
- Configuración CORS y encriptación S3
- 6 tablas DynamoDB (analytics, content, media_assets, sessions, subscriptions, users)

### Base de Datos y Cache
- ElastiCache Redis replication group
- DB subnet group
- Secretos para DB y Redis en Secrets Manager

### Load Balancer y Seguridad
- Application Load Balancer
- Target group para EKS API
- Listener HTTP redirect
- 6 Security Groups (ALB, EKS cluster, EKS nodes, ElastiCache, Lambda, RDS)

### Certificados y Monitoreo
- Certificados ACM
- CloudWatch log groups
- CloudWatch metric alarms
- SNS topics para alertas y notificaciones
- SQS queues para notificaciones
- WAF para API

## Recursos que Faltaron por Permisos ❌

### IAM Roles
- EKS cluster role
- EKS node group role
- Lambda execution roles
- RDS monitoring role
- Media Live role
- Cognito lambda execution role

### CloudFront y CDN
- Origin Access Controls
- CloudFront distributions

### Servicios Adicionales
- MediaStore container
- X-Ray sampling rule
- Lambda functions (todos fallan por falta de roles IAM)

## Plan para Nuevo Laboratorio

1. **Destruir recursos existentes** (opcional, pueden reutilizarse)
2. **Configurar nuevas credenciales AWS**
3. **Re-ejecutar terraform apply** - creará los recursos faltantes

## Comandos de Limpieza (si necesario)

```bash
# Para empezar limpio (opcional)
terraform destroy -var-file="terraform.tfvars" -auto-approve

# O para continuar desde donde se quedó
terraform apply -var-file="terraform.tfvars" -auto-approve
```
