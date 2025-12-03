# Guía de Despliegue Rápido - CNN Chile Infraestructura

## 🚀 Solución Rápida para Problemas de Despliegue

Esta guía describe cómo realizar un despliegue rápido sin necesidad de validación de certificados SSL ni permisos IAM complejos.

## 📋 Modos de Despliegue

### Modo 1: Despliegue Rápido (Recomendado para Testing/Dev)

**Características:**
- ✅ Sin HTTPS (sin validación de certificados SSL)
- ✅ Sin CloudFront (sin problemas de permisos)
- ✅ Sin MediaStore (sin permisos IAM complejos)
- ✅ Sin Lambda@Edge (sin dependencias complejas)
- ✅ ALB con HTTP
- ✅ S3, DynamoDB, VPC, EKS básico

**Tiempo estimado:** 20-30 minutos

**Uso:**
```bash
cd terraform
cp terraform.tfvars.quick-deploy terraform.tfvars
terraform init
terraform plan
terraform apply
```

### Modo 2: Despliegue con HTTPS (Requiere validación DNS)

**Características:**
- ✅ HTTPS habilitado
- ✅ CloudFront habilitado
- ⚠️ Requiere validar certificados SSL vía DNS
- ⚠️ Tiempo de validación: 20-30 minutos adicionales

**Configuración:**
```hcl
enable_https      = true
enable_cloudfront = true
enable_mediastore = false
enable_lambda_edge = false
enable_advanced_waf = false
```

**Pasos adicionales:**
1. Aplicar Terraform con certificados pendientes
2. Obtener registros DNS de validación:
   ```bash
   terraform output acm_certificate_validation_records
   ```
3. Agregar registros CNAME en tu proveedor DNS
4. Esperar validación (20-30 minutos)
5. Re-aplicar Terraform

### Modo 3: Despliegue Completo (Producción)

**Características:**
- ✅ Todo habilitado
- ⚠️ Requiere todos los permisos IAM
- ⚠️ Requiere validación de certificados
- ⚠️ Tiempo de despliegue: 60-90 minutos

**Configuración:**
```hcl
enable_https        = true
enable_cloudfront   = true
enable_mediastore   = true
enable_lambda_edge  = true
enable_advanced_waf = true
```

## 🔧 Variables de Control

Las siguientes variables controlan qué recursos se crean:

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `enable_https` | Habilita HTTPS y certificados SSL | `false` |
| `enable_cloudfront` | Habilita distribuciones CloudFront | `false` |
| `enable_mediastore` | Habilita MediaStore para streaming | `false` |
| `enable_lambda_edge` | Habilita funciones Lambda@Edge | `false` |
| `enable_advanced_waf` | Habilita reglas WAF avanzadas | `false` |
| `enable_cognito_triggers` | Habilita triggers Lambda para Cognito | `false` |

## 🐛 Solución de Problemas Comunes

### Error: Certificado SSL inválido

**Problema:** CloudFront requiere certificados SSL validados

**Solución rápida:**
```bash
# Usar modo de despliegue rápido
enable_https = false
enable_cloudfront = false
```

**Solución completa:**
1. Habilitar `enable_https = true`
2. Aplicar Terraform
3. Validar certificados SSL vía DNS
4. Re-aplicar Terraform después de validación

### Error: Permisos IAM insuficientes

**Problema:** No se pueden crear roles IAM (común en AWS Learner Lab)

**Solución:**
```bash
# Deshabilitar recursos que requieren IAM complejos
enable_mediastore = false
enable_lambda_edge = false
```

**Alternativa:** Usar roles IAM pre-existentes del Learner Lab

### Error: MediaStore container no se puede crear

**Problema:** Permisos insuficientes para MediaStore

**Solución:**
```bash
enable_mediastore = false
```

**Alternativa:** Configurar MediaStore manualmente después del despliegue

### Error: Secretos programados para eliminación

**Problema:** Secrets Manager tiene secretos pendientes de eliminación

**Solución:**
```bash
# Listar secretos programados para eliminación
aws secretsmanager list-secrets --filters Key=all,Values=all

# Recuperar secreto específico
aws secretsmanager restore-secret --secret-id <secret-name>

# O eliminar permanentemente
aws secretsmanager delete-secret --secret-id <secret-name> --force-delete-without-recovery
```

### Error: WAF configuration error

**Problema:** Reglas WAF conflictivas o mal configuradas

**Solución:**
```bash
enable_advanced_waf = false
```

## 📊 Comparación de Modos

| Característica | Modo Rápido | Modo HTTPS | Modo Completo |
|----------------|-------------|------------|---------------|
| Tiempo | 20-30 min | 50-60 min | 60-90 min |
| HTTPS | ❌ | ✅ | ✅ |
| CloudFront | ❌ | ✅ | ✅ |
| MediaStore | ❌ | ❌ | ✅ |
| Lambda@Edge | ❌ | ❌ | ✅ |
| Validación SSL | No requerida | Requerida | Requerida |
| Permisos IAM | Básicos | Medios | Completos |

## 🎯 Migración entre Modos

### De Rápido a HTTPS

1. Actualizar variables:
   ```bash
   enable_https = true
   enable_cloudfront = true
   ```

2. Aplicar cambios:
   ```bash
   terraform plan
   terraform apply
   ```

3. Validar certificados SSL (ver arriba)

4. Re-aplicar:
   ```bash
   terraform apply
   ```

### De HTTPS a Completo

1. Actualizar variables:
   ```bash
   enable_mediastore = true
   enable_lambda_edge = true
   enable_advanced_waf = true
   ```

2. Verificar permisos IAM

3. Aplicar cambios:
   ```bash
   terraform plan
   terraform apply
   ```

## 🔒 Consideraciones de Seguridad

**Modo Rápido (HTTP):**
- ⚠️ No usar en producción
- ⚠️ Datos transmitidos sin encriptación
- ✅ Apropiado para desarrollo y testing

**Modo HTTPS:**
- ✅ Encriptación TLS/SSL
- ✅ Apropiado para staging
- ⚠️ Certificados deben mantenerse válidos

**Modo Completo:**
- ✅ Máxima seguridad
- ✅ WAF avanzado
- ✅ Lambda@Edge para autorización
- ✅ Apropiado para producción

## 📝 Comandos Útiles

```bash
# Ver estado actual
terraform show

# Ver recursos creados
terraform state list

# Ver outputs
terraform output

# Validar configuración
terraform validate

# Formatear archivos
terraform fmt

# Destruir recursos (cuidado!)
terraform destroy

# Destruir recursos específicos
terraform destroy -target=aws_cloudfront_distribution.static_distribution
```

## 🆘 Soporte

Para problemas adicionales:
1. Revisar logs de Terraform
2. Verificar permisos IAM en AWS Console
3. Consultar documentación de AWS
4. Revisar límites de cuenta (Service Quotas)

## 📚 Referencias

- [AWS Learner Lab Limitations](https://awsacademy.instructure.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ACM Certificate Validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
