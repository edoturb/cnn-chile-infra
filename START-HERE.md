# 🚀 EMPIEZA AQUÍ - Solución de Despliegue Rápido

## 📌 ¿Qué es esto?

Este repositorio contiene la infraestructura de CNN Chile en AWS, ahora con una **solución rápida** para problemas de despliegue.

## ⚡ Despliegue Rápido (15-20 minutos)

### Opción 1: Comando Único (Recomendado)

```bash
cd terraform
cp terraform.tfvars.quick-deploy terraform.tfvars
terraform init -backend=false
terraform apply -auto-approve
```

### Opción 2: Paso a Paso

```bash
# 1. Ir al directorio de Terraform
cd terraform

# 2. Copiar configuración rápida
cp terraform.tfvars.quick-deploy terraform.tfvars

# 3. Inicializar Terraform (sin backend remoto)
terraform init -backend=false

# 4. Ver qué se va a crear
terraform plan

# 5. Crear la infraestructura
terraform apply
```

## 📊 ¿Qué se creará?

### ✅ Recursos Básicos (Siempre)
- VPC con subnets públicas, privadas y de base de datos
- 3 buckets S3 (media, static, live-streaming)
- 6 tablas DynamoDB
- Application Load Balancer (HTTP)
- Cognito User Pool
- Security Groups
- CloudWatch logs

### ⏸️ Recursos Avanzados (Deshabilitados por defecto)
- CloudFront (requiere certificados SSL)
- HTTPS/SSL (requiere validación DNS)
- MediaStore (requiere permisos IAM)
- Lambda@Edge (requiere permisos IAM)
- WAF avanzado

**Total estimado:** 40-60 recursos en 15-20 minutos

## 📚 Documentación por Tipo de Usuario

### 👨‍💻 Quiero Desplegar YA
→ Lee: **[DEPLOYMENT-FIX.md](./DEPLOYMENT-FIX.md)**
- Comando único para desplegar
- Qué esperar
- Próximos pasos

### 📖 Quiero Entender la Solución
→ Lee: **[SOLUTION-SUMMARY.md](./SOLUTION-SUMMARY.md)**
- Problema original
- Solución implementada
- Comparación de modos
- Troubleshooting

### 🎓 Quiero Opciones Avanzadas
→ Lee: **[QUICK-DEPLOY-GUIDE.md](./QUICK-DEPLOY-GUIDE.md)**
- Modo rápido (HTTP)
- Modo HTTPS
- Modo producción completo
- Migración entre modos

### 🏗️ Quiero Entender la Arquitectura
→ Lee: **[ARCHITECTURE-OVERVIEW.md](./ARCHITECTURE-OVERVIEW.md)**
- Componentes principales
- Stack tecnológico
- Diagramas

## 🎯 Configuración por Escenario

### Desarrollo/Testing (Ahora)
```hcl
enable_https           = false  # ✅
enable_cloudfront      = false  # ✅
enable_mediastore      = false  # ✅
enable_lambda_edge     = false  # ✅
enable_advanced_waf    = false  # ✅
enable_cognito_triggers = false  # ✅
```
**Resultado:** HTTP básico, 15-20 minutos

### Staging (Próxima Fase)
```hcl
enable_https           = true   # ⬆️ Cambio
enable_cloudfront      = true   # ⬆️ Cambio
enable_mediastore      = false
enable_lambda_edge     = false
enable_advanced_waf    = false
enable_cognito_triggers = false
```
**Resultado:** HTTPS con CloudFront, 50-60 minutos

### Producción (Meta Final)
```hcl
enable_https           = true
enable_cloudfront      = true
enable_mediastore      = true   # ⬆️ Cambio
enable_lambda_edge     = true   # ⬆️ Cambio
enable_advanced_waf    = true   # ⬆️ Cambio
enable_cognito_triggers = true   # ⬆️ Cambio
```
**Resultado:** Todo habilitado, 60-90 minutos

## 🔍 Verificar Despliegue Exitoso

```bash
# Ver recursos creados
terraform state list

# Ver outputs importantes
terraform output

# Verificar en AWS
aws s3 ls | grep cnn-chile
aws dynamodb list-tables | grep cnn-chile
```

## 🐛 ¿Algo salió mal?

### Error: Backend S3 no existe
```bash
terraform init -backend=false
```

### Error: EKS/RDS fallan
Es normal en AWS Learner Lab. Los demás recursos se crearán bien.

### Error: Secretos en eliminación
```bash
aws secretsmanager restore-secret --secret-id <id>
```

### Más problemas
→ Lee la sección **Solución de Problemas** en [QUICK-DEPLOY-GUIDE.md](./QUICK-DEPLOY-GUIDE.md#-solución-de-problemas-comunes)

## 📈 Roadmap de Despliegue

```
Fase 1 (HOY) → Despliegue Rápido
   ✅ HTTP básico
   ✅ S3 + DynamoDB
   ✅ VPC + ALB
   ⏱️ 15-20 minutos

Fase 2 (ESTA SEMANA) → HTTPS
   ⬆️ Habilitar HTTPS
   ⬆️ Validar certificados
   ⬆️ Habilitar CloudFront
   ⏱️ +30 minutos

Fase 3 (ESTE MES) → Características Avanzadas
   ⬆️ MediaStore
   ⬆️ Lambda@Edge
   ⬆️ WAF avanzado
   ⏱️ +20 minutos

Fase 4 (PRODUCCIÓN) → Optimización
   ⬆️ Monitoreo completo
   ⬆️ Backups
   ⬆️ DR plan
```

## ⚠️ Consideraciones Importantes

### Seguridad
- ⚠️ **Configuración rápida usa HTTP** (sin encriptación)
- ✅ **OK para:** Testing, desarrollo, demos
- ❌ **NO para:** Producción, datos sensibles

### Costos
- 💰 **Estimado mensual:** $50-150 (modo rápido)
- 💰 **Estimado mensual:** $200-500 (modo completo)
- 💡 **Tip:** Usa `single_nat_gateway = true` para ahorrar

### Limitaciones AWS Learner Lab
- ❌ No permite todos los roles IAM
- ❌ EKS puede fallar
- ❌ RDS puede fallar
- ✅ S3, DynamoDB, VPC funcionan bien

## 🆘 Ayuda Rápida

| Necesito... | Documento | Sección |
|-------------|-----------|---------|
| Desplegar ahora | DEPLOYMENT-FIX.md | Despliegue Rápido |
| Resolver errores | QUICK-DEPLOY-GUIDE.md | Solución de Problemas |
| Entender cambios | SOLUTION-SUMMARY.md | Solución Implementada |
| Habilitar HTTPS | QUICK-DEPLOY-GUIDE.md | Modo HTTPS |
| Ir a producción | QUICK-DEPLOY-GUIDE.md | Modo Completo |

## 💬 Preguntas Frecuentes

**P: ¿Por qué tantas características deshabilitadas?**  
R: Para despliegue rápido sin certificados SSL ni permisos IAM complejos.

**P: ¿Cuándo habilito todo?**  
R: Gradualmente, según tengas certificados validados y permisos IAM.

**P: ¿Es seguro para producción?**  
R: NO en configuración rápida. Habilita HTTPS y WAF primero.

**P: ¿Cuánto cuesta?**  
R: $50-150/mes (básico), $200-500/mes (completo).

**P: ¿Funciona en AWS Learner Lab?**  
R: Sí, modo rápido funciona. Algunos recursos pueden fallar por permisos.

## 🎓 Próximos Pasos

1. ✅ **Ahora:** Ejecutar despliegue rápido
2. ⏸️ **Hoy:** Verificar recursos creados
3. ⏸️ **Esta semana:** Configurar DNS y validar certificados
4. ⏸️ **Este mes:** Habilitar HTTPS y CloudFront
5. ⏸️ **Producción:** Habilitar características avanzadas

---

**¿Listo para empezar?** → Ejecuta los comandos de **Despliegue Rápido** arriba ⬆️

**¿Necesitas más información?** → Lee **DEPLOYMENT-FIX.md** para detalles

**¿Tienes problemas?** → Revisa **QUICK-DEPLOY-GUIDE.md** sección Troubleshooting
