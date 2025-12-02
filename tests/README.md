# 🧪 Guía Completa de Pruebas - CNN Chile Infrastructure

## 📋 Índice de Pruebas

1. [Pruebas de Infraestructura](#-pruebas-de-infraestructura)
2. [Pruebas de Aplicación](#-pruebas-de-aplicación)
3. [Pruebas de Seguridad](#-pruebas-de-seguridad)
4. [Pruebas de Performance](#-pruebas-de-performance)
5. [Pruebas End-to-End](#-pruebas-end-to-end)
6. [Monitoreo y Alertas](#-monitoreo-y-alertas)

---

## 🏗️ Pruebas de Infraestructura

### Pre-requisitos
```bash
# Verificar herramientas necesarias
aws --version
terraform --version
kubectl version --client
```

### 1. Validación de Terraform
```bash
# Validar sintaxis
cd terraform/
terraform fmt -check
terraform validate

# Planificar despliegue (dry-run)
terraform plan -var-file="environments/dev.tfvars"
```

### 2. Pruebas de Conectividad AWS
```bash
# Verificar credenciales AWS
aws sts get-caller-identity

# Listar recursos existentes
aws ec2 describe-vpcs
aws eks list-clusters
aws rds describe-db-instances
```

### 3. Validación de Kubernetes
```bash
# Verificar manifiestos
cd kubernetes/
kubectl apply --dry-run=client -f base/
kubectl apply --dry-run=client -f microservices/
```

---

## 📱 Pruebas de Aplicación

### 1. Pruebas de Microservicios Locales

#### Content Management API
```bash
cd microservices/content-management-api/
npm test
npm run test:coverage
npm run test:integration
```

#### User Management API
```bash
cd microservices/user-management-api/
npm test
npm run test:e2e
npm run test:security
```

#### Subscription API
```bash
cd microservices/subscription-api/
npm test
npm run test:payment
npm run test:billing
```

### 2. Pruebas de Lambda Functions
```bash
cd lambda/notification-service/
npm test
npm run test:local

cd lambda/event-processor/
npm test
npm run test:integration
```

### 3. Pruebas con Docker
```bash
# Construir y probar contenedores
docker-compose -f docker-compose.test.yml up --build
docker-compose -f docker-compose.test.yml down
```

---

## 🔒 Pruebas de Seguridad

### 1. Análisis de Vulnerabilidades
```bash
# Escanear dependencias
npm audit
npm audit fix

# Escanear imágenes Docker
docker scan microservices/content-management-api:latest
```

### 2. Pruebas de Autenticación
```bash
# Probar endpoints protegidos
curl -H "Authorization: Bearer <token>" \
     https://api-dev.cnnchile.com/api/v1/protected

# Verificar rate limiting
for i in {1..100}; do
  curl https://api-dev.cnnchile.com/api/v1/news
done
```

### 3. Pruebas WAF
```bash
# Intentar ataques comunes (debe ser bloqueado)
curl -X POST https://dev.cnnchile.com/ \
     -d "'; DROP TABLE users; --"

curl https://dev.cnnchile.com/?id=<script>alert('xss')</script>
```

---

## ⚡ Pruebas de Performance

### 1. Load Testing con Artillery
```bash
# Instalar Artillery
npm install -g artillery

# Ejecutar pruebas de carga
artillery run tests/load/api-load-test.yml
artillery run tests/load/website-load-test.yml
```

### 2. Pruebas de Base de Datos
```bash
# Conectar a RDS y ejecutar queries de prueba
psql -h <rds-endpoint> -U <username> -d cnnchile_db

# Ejecutar en PostgreSQL:
EXPLAIN ANALYZE SELECT * FROM articles WHERE category = 'news' LIMIT 100;
```

### 3. Pruebas CDN
```bash
# Verificar cache hit ratio
curl -I https://cdn.cnnchile.com/images/logo.png
curl -I https://cdn.cnnchile.com/videos/latest.mp4

# Verificar geolocalización
curl -H "CloudFront-Viewer-Country: US" https://cdn.cnnchile.com/api/v1/content
```

---

## 🔄 Pruebas End-to-End

### 1. Flujo Completo de Usuario
```bash
# Ejecutar suite de pruebas E2E
cd tests/e2e/
npx playwright test
npx cypress run
```

### 2. Pruebas de Integración API
```bash
# Registrar usuario
USER_ID=$(curl -X POST https://api-dev.cnnchile.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}' \
  | jq -r '.user_id')

# Suscribir usuario
curl -X POST https://api-dev.cnnchile.com/api/v1/subscriptions \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"plan_id":"premium","payment_method":"stripe"}'

# Acceder a contenido premium
curl -H "Authorization: Bearer <token>" \
     https://api-dev.cnnchile.com/api/v1/content/premium
```

### 3. Pruebas de Streaming
```bash
# Verificar endpoints de video
curl -I https://streaming.cnnchile.com/live/channel1/index.m3u8
curl -I https://streaming.cnnchile.com/vod/news-2024-12-01.mp4
```

---

## 📊 Monitoreo y Alertas

### 1. Health Checks Automatizados
```bash
# Ejecutar health check completo
./scripts/health-check.sh --comprehensive

# Verificar endpoints específicos
./scripts/health-check.sh --endpoints

# Monitoreo continuo
./scripts/health-check.sh --monitor --interval=30
```

### 2. Verificar Métricas CloudWatch
```bash
# CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=cnn-chile-cluster \
  --start-time 2024-12-01T00:00:00Z \
  --end-time 2024-12-01T23:59:59Z \
  --period 3600 \
  --statistics Average

# RDS connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=cnn-chile-db \
  --start-time 2024-12-01T00:00:00Z \
  --end-time 2024-12-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

### 3. Logs y Tracing
```bash
# Ver logs de aplicación
kubectl logs -l app=content-management-api -f

# Ver logs de Lambda
aws logs tail /aws/lambda/notification-service --follow

# X-Ray traces
aws xray get-trace-summaries \
  --time-range-type TimeRangeByStartTime \
  --start-time 2024-12-01T00:00:00 \
  --end-time 2024-12-01T23:59:59
```

---

## 🎯 Cronograma de Pruebas Recomendado

### Fase 1: Desarrollo Local (1-2 días)
- [ ] Validación de Terraform
- [ ] Pruebas unitarias de microservicios
- [ ] Pruebas de Lambda functions
- [ ] Análisis de seguridad básico

### Fase 2: Entorno de Desarrollo (2-3 días)
- [ ] Despliegue en AWS Dev
- [ ] Pruebas de integración
- [ ] Pruebas de conectividad
- [ ] Validación de configuración

### Fase 3: Testing Completo (3-5 días)
- [ ] Load testing
- [ ] Pruebas de seguridad avanzadas
- [ ] Pruebas E2E completas
- [ ] Optimización de performance

### Fase 4: Pre-Producción (2-3 días)
- [ ] Smoke tests en staging
- [ ] Pruebas de disaster recovery
- [ ] Validación de monitoreo
- [ ] Go-live readiness check

---

## 🚨 Criterios de Aprobación

### ✅ Infraestructura
- [ ] Terraform plan exitoso
- [ ] Todos los recursos AWS creados correctamente
- [ ] Conectividad entre servicios funcionando
- [ ] Backup y disaster recovery configurado

### ✅ Aplicación
- [ ] Cobertura de tests > 80%
- [ ] Todas las pruebas E2E pasando
- [ ] APIs respondiendo < 200ms (p95)
- [ ] Zero downtime deployments funcionando

### ✅ Seguridad
- [ ] Sin vulnerabilidades críticas
- [ ] WAF bloqueando ataques
- [ ] Autenticación y autorización funcionando
- [ ] Datos encriptados en tránsito y reposo

### ✅ Performance
- [ ] Soporte para 10,000+ usuarios concurrentes
- [ ] CDN cache hit ratio > 90%
- [ ] Database queries < 50ms (p95)
- [ ] Auto-scaling funcionando correctamente

---

## 📞 Contacto y Soporte

Para dudas sobre las pruebas:
- Documentación técnica: `docs/`
- Scripts de automatización: `scripts/`
- Configuraciones: `terraform/` y `kubernetes/`
