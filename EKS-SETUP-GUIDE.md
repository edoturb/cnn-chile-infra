# 🚀 CNN Chile - Guía de Creación EKS en AWS Learner Lab

## 📋 Estado Actual
- ✅ **Infraestructura Base**: VPC, subnets, security groups existentes
- ✅ **Manifiestos K8s**: Completamente preparados
- ❌ **EKS Cluster**: Requiere creación manual debido a limitaciones IAM
- ✅ **Scripts de Despliegue**: Listos para usar

## 🎯 Pasos para Crear EKS Manualmente

### 1. Crear Cluster EKS desde la Consola AWS

```bash
# Navegar a EKS en la consola AWS
# https://us-east-1.console.aws.amazon.com/eks/home
```

**Configuración del Cluster:**
- **Nombre**: `cnn-chile-dev-cluster`
- **Versión Kubernetes**: `1.28`
- **Role de Servicio**: Crear nuevo role `eks-service-role`
- **VPC**: `vpc-025aea4b75e561b62` (existente)
- **Subnets**: 
  - Private: `subnet-016c9638f42425fc5`, `subnet-09bca42ee92befe91`, `subnet-0bd8698eb4c65ee17`
  - Public: `subnet-0128b8e37a130d124`, `subnet-00de36402d3319eea`, `subnet-0fb1a850f2edc0688`
- **Security Groups**: Usar existentes
- **Endpoint Access**: Público y Privado
- **Logging**: Habilitar API, Audit, Authenticator

### 2. Crear Node Group

**Configuración del Node Group:**
- **Nombre**: `cnn-chile-dev-nodes`
- **Node IAM Role**: Crear nuevo `eks-node-role`
- **Subnets**: Solo privadas
- **Instance Types**: `t3.medium`
- **Scaling**: Min: 1, Desired: 2, Max: 4
- **Disk Size**: 20 GB
- **Remote Access**: Opcional (para debugging)

### 3. Configurar kubectl Local

```bash
# Instalar kubectl (si no está instalado)
curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.28.3/2023-11-14/bin/darwin/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin

# Configurar acceso al cluster
aws eks update-kubeconfig --region us-east-1 --name cnn-chile-dev-cluster

# Verificar conexión
kubectl cluster-info
kubectl get nodes
```

### 4. Desplegar CNN Chile en EKS

```bash
# Ejecutar script de despliegue
cd /Users/eduarditourbina/cnn-chile-infra/cnn-chile-infra
./scripts/deploy-to-eks.sh
```

## 📁 Estructura de Manifiestos Preparados

```
kubernetes/
├── config/
│   ├── configmaps.yaml      # Configuraciones de la aplicación
│   ├── secrets.yaml         # Credenciales (placeholder)
│   └── app-code.yaml        # Código Node.js para pods
├── deployment/
│   ├── cnn-chile-app.yaml   # Frontend web con Nginx
│   └── backend-services.yaml # API y streaming services
└── scripts/
    └── deploy-to-eks.sh     # Script automatizado de despliegue
```

## 🔧 Comandos Útiles Post-Despliegue

```bash
# Ver estado de todos los recursos
kubectl get all -n cnn-chile

# Logs de la aplicación
kubectl logs -f deployment/cnn-chile-web -n cnn-chile

# Port forward para testing local
kubectl port-forward service/cnn-chile-web-service 8080:80 -n cnn-chile

# Escalar aplicación
kubectl scale deployment cnn-chile-web --replicas=5 -n cnn-chile

# Actualizar imagen
kubectl set image deployment/cnn-chile-web nginx=nginx:1.25 -n cnn-chile
```

## 🌐 Acceso a la Aplicación

Una vez desplegado, la aplicación estará disponible en:

- **Load Balancer**: Obtenido automáticamente del ALB Ingress
- **URL**: `http://<ALB-DNS-NAME>/`
- **API**: `http://<ALB-DNS-NAME>/api/`
- **Streaming**: `http://<ALB-DNS-NAME>/streaming/`

## 📊 Monitoreo y Troubleshooting

```bash
# Describir recursos problemáticos
kubectl describe pod <pod-name> -n cnn-chile

# Ver eventos del namespace
kubectl get events -n cnn-chile --sort-by='.lastTimestamp'

# Ejecutar shell en pod para debugging
kubectl exec -it <pod-name> -n cnn-chile -- /bin/sh

# Ver configuración del ingress
kubectl describe ingress cnn-chile-ingress -n cnn-chile
```

## ✅ Checklist de Validación

- [ ] Cluster EKS creado y activo
- [ ] Node Group con 2+ nodos running
- [ ] kubectl configurado y conectado
- [ ] Namespace `cnn-chile` creado
- [ ] Pods de aplicación en estado Running
- [ ] Services expuestos correctamente
- [ ] Ingress configurado con ALB
- [ ] Aplicación accesible desde internet

## 🚨 Limitaciones Conocidas

1. **IAM Roles**: Deben crearse manualmente en la consola
2. **Secrets**: Usar valores placeholder hasta configurar AWS Secrets Manager
3. **Ingress**: Requiere AWS Load Balancer Controller
4. **Certificates**: Configurar manualmente en ALB

## 📞 Siguiente Paso

Una vez completado el EKS, ejecutar:
```bash
./scripts/deploy-to-eks.sh
```

¡La migración a Kubernetes estará completa! 🎉
