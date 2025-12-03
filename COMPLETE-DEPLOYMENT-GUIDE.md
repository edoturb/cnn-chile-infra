# 🚀 Guía Completa de Despliegue - CNN Chile Infrastructure

## 📋 Contexto

Has creado exitosamente un cluster EKS en el nuevo laboratorio de AWS con más permisos. Este documento te guía para completar el despliegue de toda la infraestructura CNN Chile.

## 🎯 Estado Actual

### ✅ Recursos ya Creados
Según `DEPLOYMENT-STATE.md`, ya tienes:
- **Red completa**: VPC, subnets, gateways, route tables
- **Almacenamiento**: 3 buckets S3, 6 tablas DynamoDB
- **Base de datos y caché**: ElastiCache Redis, subnet groups, secretos
- **Load Balancer**: ALB, target groups, listeners
- **Seguridad**: 6 security groups, WAF, certificados ACM
- **Monitoreo**: CloudWatch logs y métricas, SNS, SQS
- **EKS Cluster**: confused-bluegrass-walrus (creado manualmente)

### ⏳ Recursos Pendientes (26 recursos)
- Roles IAM adicionales (si LabRole no es suficiente)
- CloudFront distributions (2-3 distribuciones)
- Lambda functions (5-7 funciones)
- MediaStore container
- X-Ray sampling rules
- Posiblemente RDS instance

## 🔧 Preparación

### 1. Verificar Acceso y Permisos

```bash
# Verificar identidad AWS
aws sts get-caller-identity

# Verificar acceso al cluster EKS
aws eks describe-cluster --name confused-bluegrass-walrus --region us-east-1

# Ejecutar script de verificación de recursos
./scripts/verify-resources.sh
```

### 2. Configurar kubectl para EKS Existente

```bash
# Configurar kubeconfig
aws eks update-kubeconfig --region us-east-1 --name confused-bluegrass-walrus

# Verificar conexión
kubectl cluster-info
kubectl get nodes

# Nota: Si no ves nodos, es normal en EKS Auto Mode
# Los nodos se crean automáticamente cuando despliegas aplicaciones
```

### 3. Inicializar Terraform (si no lo has hecho)

```bash
cd terraform

# Inicializar backend y providers
terraform init

# Verificar configuración
terraform validate
```

## 🛠️ Opción A: Despliegue Completo con Terraform

### Estrategia 1: Crear Todo desde Terraform (Recomendado para consistencia)

**ADVERTENCIA**: Esto intentará crear un NUEVO cluster EKS, lo que podría fallar o crear duplicados. Si prefieres usar el cluster existente, salta a la Opción B.

```bash
cd terraform

# Ver qué se va a crear
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Revisar el plan cuidadosamente
terraform show tfplan

# Si todo se ve bien, aplicar
terraform apply tfplan
```

**Tiempo estimado**: 40-60 minutos

**Recursos que se crearán**:
- Nuevo cluster EKS (si no usas el existente)
- Roles IAM que faltan
- CloudFront distributions
- Lambda functions
- MediaStore
- X-Ray
- RDS (si está configurado)

## 🔄 Opción B: Usar Cluster EKS Existente + Recursos Complementarios

### Paso 1: Configurar Terraform para Usar Cluster Existente

Tienes dos opciones:

#### Opción B1: Importar el Cluster a Terraform

```bash
cd terraform

# Importar el cluster existente
terraform import aws_eks_cluster.main confused-bluegrass-walrus

# Esto registrará el cluster en el estado de Terraform
# Pero necesitarás ajustar eks.tf para que coincida
```

#### Opción B2: Usar Data Sources (Más Seguro)

```bash
cd terraform

# Habilitar data sources en eks-existing.tf
# Descomentar las líneas en ese archivo:
nano eks-existing.tf
# O usar tu editor favorito

# Comentar recursos en eks.tf que crean cluster nuevo
# (aws_eks_cluster.main, aws_iam_role.eks_cluster, etc.)
```

Edita `terraform/main.tf` para actualizar los providers:

```hcl
# Reemplazar en main.tf:

provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.existing.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.existing.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.existing.token
  }
}
```

### Paso 2: Desplegar Solo Recursos Faltantes

```bash
cd terraform

# Planificar solo recursos específicos
terraform plan \
  -target=aws_cloudfront_distribution.main \
  -target=aws_lambda_function.edge_auth \
  -target=aws_lambda_function.notification_processor \
  -target=aws_media_store_container.live_streaming \
  -target=aws_xray_sampling_rule.main \
  -var-file="terraform.tfvars"

# Si el plan se ve bien, aplicar
terraform apply \
  -target=aws_cloudfront_distribution.main \
  -target=aws_lambda_function.edge_auth \
  -target=aws_lambda_function.notification_processor \
  -target=aws_media_store_container.live_streaming \
  -target=aws_xray_sampling_rule.main \
  -var-file="terraform.tfvars"
```

**Tiempo estimado**: 15-25 minutos

## 📦 Desplegar Aplicaciones al Cluster EKS

### Paso 1: Preparar Namespaces

```bash
# Crear namespace para la aplicación
kubectl create namespace cnn-chile-dev

# Verificar
kubectl get namespaces
```

### Paso 2: Aplicar Manifiestos de Kubernetes

```bash
# Desde la raíz del proyecto
cd /home/runner/work/cnn-chile-infra/cnn-chile-infra

# Aplicar en orden
kubectl apply -f kubernetes/namespaces/
kubectl apply -f kubernetes/config-maps/
kubectl apply -f kubernetes/secrets/
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/

# O usar el script automatizado
./scripts/deploy-to-eks.sh
```

### Paso 3: Verificar Despliegue

```bash
# Ver todos los recursos
kubectl get all -n cnn-chile-dev

# Ver pods específicos
kubectl get pods -n cnn-chile-dev -o wide

# Ver logs de un pod
kubectl logs -n cnn-chile-dev -l app=content-api --tail=50

# Ver servicios
kubectl get services -n cnn-chile-dev

# Ver ingress
kubectl get ingress -n cnn-chile-dev
```

**Nota sobre EKS Auto Mode**: Si no ves nodos inmediatamente, espera 5-10 minutos. EKS Auto Mode crea nodos automáticamente cuando hay pods pendientes.

```bash
# Monitorear creación de nodos
watch kubectl get nodes
```

## 🔍 Verificación Post-Despliegue

### 1. Health Checks de Infraestructura

```bash
# Ejecutar script de health check
./scripts/health-check.sh

# O verificar manualmente cada componente
```

### 2. Verificar Endpoints

```bash
# Si tienes dominios configurados
curl -I https://api-dev.cnnchile.com/health
curl -I https://cdn-dev.cnnchile.com

# Verificar ALB
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[0].DNSName' \
  --output text)
curl -I http://$ALB_DNS
```

### 3. Verificar Logs y Métricas

```bash
# CloudWatch logs
aws logs tail /aws/eks/confused-bluegrass-walrus/cluster --follow

# Métricas de CloudWatch
aws cloudwatch list-metrics --namespace AWS/EKS
```

### 4. Verificar Lambda Functions

```bash
# Listar funciones
aws lambda list-functions --query 'Functions[*].FunctionName'

# Probar una función
aws lambda invoke \
  --function-name cnn-chile-dev-edge-auth \
  --payload '{}' \
  response.json
cat response.json
```

### 5. Verificar CloudFront

```bash
# Listar distribuciones
aws cloudfront list-distributions \
  --query 'DistributionList.Items[*].[Id,DomainName,Status]' \
  --output table
```

## 🎨 Arquitectura Final

Después del despliegue completo, tendrás:

```
┌─────────────────────────────────────────────────────────────┐
│                         CloudFront CDN                       │
│              (Distribución global de contenido)              │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────┐
│                   Application Load Balancer                  │
│                    (Distribución de tráfico)                 │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
    ┌────▼────┐                    ┌────▼────┐
    │   EKS   │                    │ Lambda  │
    │ Cluster │                    │Functions│
    │ (Auto)  │                    └─────────┘
    └────┬────┘                          
         │                                    
    ┌────▼────────────────┐                  
    │  Microservicios     │                  
    │  - Content API      │                  
    │  - Streaming API    │                  
    │  - User API         │                  
    │  - Payment API      │                  
    └──────┬──────────────┘                  
           │                                  
    ┌──────┴──────────────┐                  
    │                     │                  
┌───▼───┐            ┌────▼─────┐           
│  RDS  │            │DynamoDB  │           
│(Postgre)│          │  Tables  │           
└───────┘            └──────────┘           
                                             
┌────────────────────────────────────────┐  
│        Servicios Complementarios       │  
│  - ElastiCache Redis (caché)          │  
│  - S3 Buckets (almacenamiento)        │  
│  - MediaStore (streaming)             │  
│  - CloudWatch (monitoreo)             │  
│  - X-Ray (tracing)                    │  
│  - WAF (seguridad)                    │  
└────────────────────────────────────────┘  
```

## 📊 Monitoreo Continuo

### Comandos Útiles

```bash
# Monitorear cluster EKS
./scripts/monitor-eks.sh

# Ver estado de pods en tiempo real
watch kubectl get pods -n cnn-chile-dev

# Ver uso de recursos
kubectl top nodes
kubectl top pods -n cnn-chile-dev

# Ver eventos
kubectl get events -n cnn-chile-dev --sort-by='.lastTimestamp'
```

### Dashboards Recomendados

1. **EKS Console**: https://console.aws.amazon.com/eks/
2. **CloudWatch**: https://console.aws.amazon.com/cloudwatch/
3. **X-Ray**: https://console.aws.amazon.com/xray/

## 🐛 Solución de Problemas

### Problema: No puedo conectarme al cluster EKS

```bash
# Reconfigurar kubeconfig
aws eks update-kubeconfig --region us-east-1 --name confused-bluegrass-walrus --force

# Verificar AWS credentials
aws sts get-caller-identity

# Verificar permisos en el cluster
aws eks describe-cluster --name confused-bluegrass-walrus --region us-east-1
```

### Problema: Terraform falla al crear recursos

```bash
# Ver errores detallados
TF_LOG=DEBUG terraform apply -var-file="terraform.tfvars" 2>&1 | tee terraform-debug.log

# Verificar permisos IAM
aws iam get-user

# Verificar límites de servicio
aws service-quotas list-service-quotas --service-code eks
```

### Problema: Pods están en estado Pending

```bash
# Verificar por qué está pendiente
kubectl describe pod <pod-name> -n cnn-chile-dev

# Verificar si hay nodos disponibles
kubectl get nodes

# En EKS Auto Mode, esperar 5-10 minutos para que se creen nodos
# Verificar eventos del cluster
kubectl get events -n cnn-chile-dev --field-selector type=Warning
```

### Problema: Lambda functions fallan

```bash
# Ver logs de Lambda
aws logs tail /aws/lambda/cnn-chile-dev-function-name --follow

# Verificar rol IAM
aws lambda get-function --function-name cnn-chile-dev-function-name

# Probar localmente
cd lambda/function-name
npm test
```

### Problema: CloudFront no se despliega

```bash
# Verificar distribuciones
aws cloudfront list-distributions

# Ver detalles de error
aws cloudfront get-distribution --id <distribution-id>

# Verificar certificado SSL
aws acm list-certificates --region us-east-1
```

## 📈 Optimización y Mejores Prácticas

### 1. Costos
- Monitorea el uso con AWS Cost Explorer
- Usa SPOT instances para nodos no críticos
- Configura auto-scaling apropiadamente
- Revisa recursos no utilizados regularmente

### 2. Seguridad
- Mantén roles IAM con mínimos privilegios
- Actualiza regularmente las imágenes de contenedores
- Usa secrets en AWS Secrets Manager, no en código
- Habilita logging y auditoría

### 3. Rendimiento
- Usa CloudFront para contenido estático
- Configura ElastiCache apropiadamente
- Optimiza consultas a DynamoDB
- Monitorea métricas con X-Ray

### 4. Disponibilidad
- Despliega en múltiples AZs
- Configura health checks apropiados
- Implementa circuit breakers
- Ten un plan de disaster recovery

## 🎯 Checklist de Despliegue Completo

Usa este checklist para verificar que todo está desplegado:

- [ ] EKS Cluster activo y accesible
- [ ] kubectl configurado correctamente
- [ ] Todos los namespaces creados
- [ ] Aplicaciones desplegadas y running
- [ ] Services expuestos correctamente
- [ ] Ingress configurado (si aplica)
- [ ] CloudFront distributions activas
- [ ] Lambda functions desplegadas y operativas
- [ ] DynamoDB tables creadas y pobladas
- [ ] RDS instance running (si aplica)
- [ ] ElastiCache Redis accesible
- [ ] S3 buckets configurados con contenido
- [ ] MediaStore container para streaming
- [ ] CloudWatch logs funcionando
- [ ] X-Ray tracing habilitado
- [ ] WAF rules activas
- [ ] SNS/SQS para notificaciones
- [ ] Secrets Manager con credenciales
- [ ] Health checks pasando
- [ ] Endpoints respondiendo correctamente
- [ ] Monitoreo y alertas configuradas

## 📚 Recursos Adicionales

- **AWS EKS Documentation**: https://docs.aws.amazon.com/eks/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **CNN Chile Architecture**: Ver `ARCHITECTURE-OVERVIEW.md`
- **Testing Guide**: Ver `TESTING-GUIDE.md`

## 🆘 Soporte

Si encuentras problemas:

1. Revisa este documento y `EKS-INTEGRATION-GUIDE.md`
2. Ejecuta `./scripts/verify-resources.sh` para diagnóstico
3. Revisa logs con `kubectl logs` y CloudWatch
4. Consulta documentación de AWS para tu servicio específico

## ✅ Próximos Pasos

Una vez completado el despliegue:

1. **Pruebas**: Ejecuta suite de pruebas con `./scripts/run-tests.sh`
2. **Monitoreo**: Configura dashboards personalizados
3. **CI/CD**: Integra con tu pipeline de deployment
4. **Documentación**: Actualiza docs con configuraciones específicas
5. **Optimización**: Ajusta recursos según métricas de uso real

---

**¡Buena suerte con tu despliegue!** 🚀

Si sigues esta guía paso a paso, deberías tener toda la infraestructura de CNN Chile funcionando en tu nuevo laboratorio de AWS.
