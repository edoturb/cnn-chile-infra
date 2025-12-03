# 🚀 Guía de Integración con EKS Existente

## 📋 Resumen

Este documento explica cómo integrar el cluster EKS existente **confused-bluegrass-walrus** con la infraestructura de Terraform para CNN Chile y completar el despliegue de los recursos restantes.

## 🎯 Cluster EKS Existente

### Información del Cluster
```yaml
Nombre: confused-bluegrass-walrus
Estado: Activo
Versión: Kubernetes 1.34
Modo: EKS Automático (Auto Mode)
Región: us-east-1
ARN: arn:aws:eks:us-east-1:220017832616:cluster/confused-bluegrass-walrus

Punto de enlace API:
  https://1690974EB32AEBFA4FCDBF6E07A99F4A.gr7.us-east-1.eks.amazonaws.com

Roles IAM:
  Cluster Role: arn:aws:iam::220017832616:role/c181773a4680376l11910160t1w220017-LabEksClusterRole-EAL858VZhhsq
  Node Role: arn:aws:iam::220017832616:role/LabRole
```

### Características del Modo Automático
✅ **Ventajas del EKS Auto Mode:**
- AWS gestiona automáticamente los nodos de trabajo
- Escalado automático de compute, storage y network
- Optimización de costos automática
- Menos configuración manual requerida
- No se necesita crear node groups manualmente

## 🔧 Opción 1: Usar el Cluster Existente (Recomendado)

### Paso 1: Configurar kubectl para el Cluster Existente

```bash
# Configurar kubeconfig para conectarse al cluster existente
aws eks update-kubeconfig \
  --region us-east-1 \
  --name confused-bluegrass-walrus

# Verificar conexión
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### Paso 2: Importar el Cluster a Terraform (Opcional)

Si deseas gestionar el cluster existente con Terraform:

```bash
cd terraform

# Importar el cluster EKS existente
terraform import aws_eks_cluster.main confused-bluegrass-walrus

# Nota: También necesitarás ajustar el código de terraform/eks.tf
# para que coincida con la configuración actual del cluster
```

### Paso 3: Modificar terraform/eks.tf para Usar Recursos Existentes

Crea un archivo `terraform/eks-existing.tf`:

```hcl
# Usar data source para referenciar el cluster existente
data "aws_eks_cluster" "existing" {
  name = "confused-bluegrass-walrus"
}

data "aws_eks_cluster_auth" "existing" {
  name = "confused-bluegrass-walrus"
}

# Usar los roles IAM existentes
data "aws_iam_role" "eks_cluster_existing" {
  name = "c181773a4680376l11910160t1w220017-LabEksClusterRole-EAL858VZhhsq"
}

data "aws_iam_role" "eks_node_existing" {
  name = "LabRole"
}

# Actualizar providers para usar el cluster existente
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

### Paso 4: Desplegar Aplicaciones al Cluster Existente

```bash
# Configurar el contexto de kubectl
kubectl config use-context arn:aws:eks:us-east-1:220017832616:cluster/confused-bluegrass-walrus

# Crear namespace para CNN Chile
kubectl create namespace cnn-chile-dev

# Aplicar manifiestos de Kubernetes
kubectl apply -f kubernetes/namespaces/
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/

# Verificar despliegue
kubectl get pods -n cnn-chile-dev
kubectl get services -n cnn-chile-dev
```

## 🏗️ Opción 2: Crear Infraestructura Complementaria

### Recursos que Aún Necesitas Desplegar

Basado en el estado actual, estos son los recursos que faltan por permisos:

#### 1. Roles IAM Adicionales (si son necesarios)
```bash
# Verificar qué roles existen
aws iam list-roles | grep -E "cnn-chile|lambda|rds"

# Si los roles no existen, crearlos con terraform
cd terraform
terraform apply -target=aws_iam_role.lambda_execution_role
terraform apply -target=aws_iam_role.rds_monitoring
```

#### 2. CloudFront para CDN
```bash
# Desplegar CloudFront distributions
terraform apply -target=aws_cloudfront_distribution.main
terraform apply -target=aws_cloudfront_origin_access_control.main
```

#### 3. Lambda Functions
```bash
# Desplegar funciones Lambda
terraform apply -target=aws_lambda_function.edge_auth
terraform apply -target=aws_lambda_function.notification_processor
terraform apply -target=aws_lambda_function.media_transcoder
```

#### 4. MediaStore para Streaming
```bash
# Crear container MediaStore
terraform apply -target=aws_media_store_container.live_streaming
```

#### 5. X-Ray para Tracing
```bash
# Configurar X-Ray
terraform apply -target=aws_xray_sampling_rule.main
```

## 🔍 Verificación de Recursos Existentes

### Script de Verificación

```bash
#!/bin/bash
echo "🔍 Verificando recursos existentes en AWS..."

# Verificar EKS Cluster
echo -e "\n📦 EKS Cluster:"
aws eks describe-cluster \
  --name confused-bluegrass-walrus \
  --region us-east-1 \
  --query 'cluster.[name,status,version]' \
  --output table

# Verificar VPC y Subnets
echo -e "\n🌐 VPC y Subnets:"
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=CNN-Chile" \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Verificar S3 Buckets
echo -e "\n💾 S3 Buckets:"
aws s3 ls | grep cnn-chile

# Verificar DynamoDB Tables
echo -e "\n🗄️ DynamoDB Tables:"
aws dynamodb list-tables --query 'TableNames[?contains(@, `cnn`) || contains(@, `CNN`)]'

# Verificar ElastiCache
echo -e "\n⚡ ElastiCache Redis:"
aws elasticache describe-replication-groups \
  --query 'ReplicationGroups[*].[ReplicationGroupId,Status,NodeGroups[0].PrimaryEndpoint.Address]' \
  --output table

# Verificar RDS
echo -e "\n🐘 RDS Instances:"
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion]' \
  --output table

# Verificar Load Balancers
echo -e "\n⚖️ Load Balancers:"
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]' \
  --output table

echo -e "\n✅ Verificación completada"
```

Guarda este script como `scripts/verify-resources.sh` y ejecútalo:

```bash
chmod +x scripts/verify-resources.sh
./scripts/verify-resources.sh
```

## 📊 Estado de Recursos - Resumen

### ✅ Recursos Ya Creados
- VPC y networking completo
- 3 buckets S3 (streaming, media, static)
- 6 tablas DynamoDB (users, sessions, content, subscriptions, media_assets, analytics)
- ElastiCache Redis
- Load Balancer (ALB)
- Security Groups
- CloudWatch logs y métricas
- SNS topics y SQS queues
- WAF para API
- Secrets Manager (DB password, Redis auth)

### ⏳ Pendientes (26 recursos)
- Roles IAM adicionales (si no existen como LabRole)
- CloudFront distributions
- Lambda functions (dependen de roles)
- MediaStore container
- X-Ray sampling rules
- RDS instance (si necesaria)

## 🚀 Plan de Despliegue Recomendado

### Fase 1: Verificación (5 minutos)
```bash
# 1. Verificar acceso al cluster
kubectl get nodes

# 2. Ejecutar script de verificación
./scripts/verify-resources.sh

# 3. Verificar permisos IAM
aws sts get-caller-identity
aws iam list-roles | head -20
```

### Fase 2: Desplegar Recursos Faltantes (30-45 minutos)
```bash
# 1. Inicializar Terraform (si no lo has hecho)
cd terraform
terraform init

# 2. Planificar cambios
terraform plan -var-file="terraform.tfvars" -out=tfplan

# 3. Revisar el plan
terraform show tfplan

# 4. Aplicar solo recursos faltantes
terraform apply tfplan

# O aplicar de forma selectiva
terraform apply -target=module.cloudfront
terraform apply -target=module.lambda
```

### Fase 3: Desplegar Aplicaciones (15-20 minutos)
```bash
# 1. Aplicar manifiestos de Kubernetes
./scripts/deploy-to-eks.sh

# 2. Verificar despliegue
kubectl get all -n cnn-chile-dev

# 3. Verificar ingress y servicios
kubectl get ingress -n cnn-chile-dev
kubectl get svc -n cnn-chile-dev
```

### Fase 4: Pruebas y Validación (10 minutos)
```bash
# 1. Ejecutar health checks
./scripts/health-check.sh

# 2. Probar endpoints
curl https://api-dev.cnnchile.com/health
curl https://cdn-dev.cnnchile.com

# 3. Revisar logs
kubectl logs -n cnn-chile-dev -l app=content-api --tail=50
```

## 🛠️ Solución de Problemas

### Error: No se puede conectar al cluster
```bash
# Reconfigurar kubeconfig
aws eks update-kubeconfig --region us-east-1 --name confused-bluegrass-walrus

# Verificar credenciales AWS
aws sts get-caller-identity

# Verificar permisos EKS
aws eks describe-cluster --name confused-bluegrass-walrus --region us-east-1
```

### Error: Terraform no puede crear recursos
```bash
# Verificar permisos del usuario actual
aws iam get-user

# Verificar roles disponibles
aws iam list-roles | grep -i lab

# Usar roles existentes en lugar de crear nuevos
# Modificar terraform/eks.tf para usar data sources
```

### EKS Auto Mode: Sin Nodos Visibles
```bash
# En modo automático, los nodos se crean bajo demanda
# Desplegar una aplicación para que EKS cree nodos

kubectl create deployment test-nginx --image=nginx
kubectl scale deployment test-nginx --replicas=3

# Esperar 5-10 minutos y verificar
kubectl get nodes
```

## 📚 Referencias

- [AWS EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [Kubernetes on AWS](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Terraform EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

## 🎯 Próximos Pasos

1. **Inmediato:** Configurar kubectl y verificar acceso al cluster existente
2. **Corto plazo:** Desplegar aplicaciones CNN Chile al cluster
3. **Mediano plazo:** Completar recursos complementarios (Lambda, CloudFront)
4. **Largo plazo:** Monitoreo, optimización y escalado

## 💡 Consejos

- **No elimines el cluster existente** - Está funcionando y en modo automático
- **Usa data sources** en Terraform para referenciar recursos existentes
- **Despliega gradualmente** - Verifica cada componente antes de continuar
- **Monitorea costos** - EKS Auto Mode optimiza, pero revisa regularmente
- **Documenta cambios** - Mantén registro de configuraciones y decisiones

---

**¡Tu cluster EKS está listo para recibir aplicaciones!** 🎉
