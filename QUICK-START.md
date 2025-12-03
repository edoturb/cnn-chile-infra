# ⚡ Quick Start - CNN Chile Infrastructure

## 🚀 Inicio Rápido para Nuevo Laboratorio AWS

Este documento te permite empezar rápidamente con el cluster EKS existente y completar el despliegue.

## 📝 Prerrequisitos

- AWS CLI instalado y configurado
- kubectl instalado (v1.28 o superior)
- Terraform instalado (v1.0+)
- Acceso al laboratorio AWS con permisos extendidos

## ⚡ 3 Pasos Rápidos

### 1️⃣ Configurar Acceso al Cluster EKS (2 minutos)

```bash
# Configurar kubectl para el cluster existente
aws eks update-kubeconfig --region us-east-1 --name confused-bluegrass-walrus

# Verificar conexión
kubectl get nodes
kubectl cluster-info
```

**Nota**: Si no ves nodos, es normal con EKS Auto Mode. Los nodos se crean automáticamente cuando despliegas aplicaciones.

### 2️⃣ Verificar Recursos Existentes (2 minutos)

```bash
# Ejecutar script de verificación
./scripts/verify-resources.sh

# O verificar manualmente el cluster
aws eks describe-cluster --name confused-bluegrass-walrus --region us-east-1
```

### 3️⃣ Desplegar Aplicaciones (10-15 minutos)

```bash
# Opción A: Desplegar con script automatizado
./scripts/deploy-to-eks.sh

# Opción B: Desplegar manualmente
kubectl create namespace cnn-chile-dev
kubectl apply -f kubernetes/namespaces/
kubectl apply -f kubernetes/deployments/
kubectl apply -f kubernetes/services/
kubectl apply -f kubernetes/ingress/

# Verificar despliegue
kubectl get all -n cnn-chile-dev
```

## 🎯 Comandos Más Útiles

### Ver Estado del Cluster
```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get services -A
```

### Ver Logs de Aplicación
```bash
kubectl logs -n cnn-chile-dev -l app=content-api --tail=50 -f
```

### Escalar Aplicación
```bash
kubectl scale deployment content-api --replicas=3 -n cnn-chile-dev
```

### Ver Recursos del Cluster
```bash
kubectl top nodes
kubectl top pods -n cnn-chile-dev
```

### Acceder a un Pod
```bash
kubectl exec -it <pod-name> -n cnn-chile-dev -- /bin/bash
```

## 📦 Información del Cluster Existente

```yaml
Cluster Name: confused-bluegrass-walrus
Status: Active
Version: Kubernetes 1.34
Mode: EKS Auto Mode
Region: us-east-1
Account: 220017832616

IAM Roles:
  Cluster: c181773a4680376l11910160t1w220017-LabEksClusterRole-EAL858VZhhsq
  Nodes: LabRole

Features:
  ✅ Auto Mode (gestión automática de nodos)
  ✅ Auto-scaling de recursos
  ✅ Optimización de costos
  ✅ Logs habilitados
```

## 🔧 Completar Recursos Faltantes (Opcional)

Si necesitas desplegar recursos adicionales con Terraform:

```bash
cd terraform

# Inicializar (primera vez)
terraform init

# Ver qué se va a crear
terraform plan -var-file="terraform.tfvars"

# Aplicar solo recursos específicos
terraform apply \
  -target=aws_lambda_function.notification_processor \
  -target=aws_cloudfront_distribution.main \
  -var-file="terraform.tfvars"
```

## 📊 Monitoreo

### Ver Estado en Tiempo Real
```bash
# Monitorear pods
watch kubectl get pods -n cnn-chile-dev

# Ver eventos
kubectl get events -n cnn-chile-dev --sort-by='.lastTimestamp'

# Script de monitoreo automatizado
./scripts/monitor-eks.sh
```

### CloudWatch Logs
```bash
# Ver logs del cluster
aws logs tail /aws/eks/confused-bluegrass-walrus/cluster --follow

# Ver logs de aplicaciones
aws logs tail /aws/eks/confused-bluegrass-walrus/application --follow
```

## 🐛 Solución Rápida de Problemas

### No puedo conectarme al cluster
```bash
# Reconfigurar kubeconfig
aws eks update-kubeconfig --region us-east-1 --name confused-bluegrass-walrus --force

# Verificar credenciales
aws sts get-caller-identity
```

### Pods en Pending
```bash
# Ver por qué está pendiente
kubectl describe pod <pod-name> -n cnn-chile-dev

# En EKS Auto Mode, esperar 5-10 min para que se creen nodos automáticamente
```

### Error de permisos
```bash
# Verificar usuario actual
aws sts get-caller-identity

# Verificar permisos del cluster
aws eks describe-cluster --name confused-bluegrass-walrus --region us-east-1
```

## 📚 Documentación Completa

Para información más detallada, consulta:

- **[EKS-INTEGRATION-GUIDE.md](EKS-INTEGRATION-GUIDE.md)** - Guía completa de integración con EKS
- **[COMPLETE-DEPLOYMENT-GUIDE.md](COMPLETE-DEPLOYMENT-GUIDE.md)** - Guía paso a paso del despliegue completo
- **[EKS-CLUSTER-STATUS.md](EKS-CLUSTER-STATUS.md)** - Estado actual del cluster
- **[DEPLOYMENT-STATE.md](DEPLOYMENT-STATE.md)** - Recursos ya creados
- **[ARCHITECTURE-OVERVIEW.md](ARCHITECTURE-OVERVIEW.md)** - Visión general de la arquitectura

## 🎯 Checklist Rápido

- [ ] AWS CLI configurado con credenciales correctas
- [ ] kubectl instalado y configurado
- [ ] Acceso al cluster EKS verificado (`kubectl get nodes`)
- [ ] Namespace cnn-chile-dev creado
- [ ] Aplicaciones desplegadas
- [ ] Pods en estado Running
- [ ] Services expuestos
- [ ] Health checks pasando

## 💡 Próximos Pasos

1. **Ahora**: Desplegar aplicaciones básicas al cluster
2. **Luego**: Completar recursos complementarios (Lambda, CloudFront)
3. **Después**: Configurar monitoreo y alertas
4. **Finalmente**: Ejecutar pruebas de carga y optimizar

## 🆘 ¿Necesitas Ayuda?

1. Ejecuta el script de diagnóstico:
   ```bash
   ./scripts/verify-resources.sh
   ```

2. Revisa los logs:
   ```bash
   kubectl logs -n cnn-chile-dev <pod-name>
   ```

3. Consulta las guías detalladas en este repositorio

---

**¡Tu cluster EKS está listo! Ahora solo necesitas desplegar tus aplicaciones.** 🎉

**Tiempo estimado total**: 15-20 minutos para tener aplicaciones corriendo
