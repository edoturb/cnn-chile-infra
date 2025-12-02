# 🧪 Guía de Pruebas - CNN Chile Infrastructure

Este documento describe cómo ejecutar las diferentes tipos de pruebas en el proyecto de infraestructura de CNN Chile.

## 📁 Estructura de Pruebas

```
tests/
├── README.md                     # Documentación completa de pruebas
├── load/                        # Pruebas de carga con Artillery
│   ├── api-load-test.yml       # Tests de API
│   ├── website-load-test.yml   # Tests de website
│   └── test-data.csv           # Datos de prueba
├── e2e/                        # Pruebas End-to-End
│   ├── playwright.config.js    # Configuración Playwright
│   ├── global-setup.js         # Setup global
│   ├── global-teardown.js      # Cleanup global
│   └── specs/                  # Especificaciones de prueba
│       ├── homepage.spec.js    # Pruebas homepage
│       ├── authentication.spec.js # Pruebas auth
│       └── subscription.spec.js   # Pruebas suscripciones
└── test-results/               # Resultados (auto-generado)
```

## 🚀 Ejecución Rápida

### Ejecutar Todas las Pruebas
```bash
./scripts/run-tests.sh --all-tests
```

### Ejecutar Pruebas Específicas
```bash
# Solo pruebas unitarias
./scripts/run-tests.sh --unit-tests-only

# Solo pruebas de integración
./scripts/run-tests.sh --integration-tests-only

# Solo pruebas de seguridad
./scripts/run-tests.sh --security-tests-only

# Solo pruebas E2E
./scripts/run-tests.sh --e2e-tests-only

# Solo pruebas de carga
./scripts/run-tests.sh --load-tests-only
```

### Ejecutar en Diferentes Entornos
```bash
./scripts/run-tests.sh --environment dev
./scripts/run-tests.sh --environment staging
./scripts/run-tests.sh --environment prod
```

## 🧪 Tipos de Pruebas

### 1. Pruebas de Infraestructura
Valida la configuración de Terraform y Kubernetes:
```bash
# Validar Terraform
cd terraform/
terraform validate
terraform plan

# Validar Kubernetes
kubectl apply --dry-run=client -f kubernetes/
```

### 2. Pruebas Unitarias
Pruebas de código individual de microservicios:
```bash
cd microservices/content-management-api/
npm test
npm run test:coverage
```

### 3. Pruebas de Integración
Pruebas entre servicios:
```bash
docker-compose -f docker-compose.test.yml up
```

### 4. Pruebas de Seguridad
```bash
# Audit de dependencias
npm audit

# Escaneo de contenedores (requiere trivy)
trivy fs --format json microservices/
```

### 5. Pruebas End-to-End
```bash
cd tests/e2e/
npm install
npx playwright test
```

### 6. Pruebas de Carga
```bash
# Instalar Artillery
npm install -g artillery

# Ejecutar pruebas
artillery run tests/load/api-load-test.yml
artillery run tests/load/website-load-test.yml
```

## 📊 Interpretación de Resultados

### Ubicación de Resultados
Los resultados se guardan en `test-results/` con timestamp:
- `terraform-plan-TIMESTAMP.log` - Resultados Terraform
- `k8s-validation.log` - Validación Kubernetes  
- `*-unit-tests.json` - Resultados pruebas unitarias
- `playwright-results.json` - Resultados E2E
- `load-test-*.json` - Resultados pruebas de carga

### Reporte HTML
Se genera un reporte HTML completo:
```bash
open test-results/test-report-TIMESTAMP.html
```

## 🎯 Criterios de Aprobación

### ✅ Infraestructura
- [ ] `terraform validate` exitoso
- [ ] `terraform plan` sin errores
- [ ] Manifiestos K8s válidos
- [ ] Conectividad AWS confirmada

### ✅ Aplicación
- [ ] Cobertura > 80% en pruebas unitarias
- [ ] 0 vulnerabilidades críticas
- [ ] Todas las pruebas E2E pasan
- [ ] APIs responden < 200ms p95

### ✅ Performance
- [ ] Soporte 10,000+ usuarios concurrentes
- [ ] CDN cache hit ratio > 90%
- [ ] Base de datos < 50ms p95
- [ ] Auto-scaling funcional

## 🐛 Resolución de Problemas

### Errores Comunes

**Terraform**
```bash
# Error: Backend not configured
terraform init

# Error: Provider version conflict  
rm -rf .terraform/
terraform init
```

**Kubernetes**
```bash
# Error: No context
aws eks update-kubeconfig --region us-east-1 --name cnn-chile-cluster

# Error: Permissions
kubectl auth can-i create pods --namespace default
```

**Playwright**
```bash
# Error: Browsers not installed
npx playwright install

# Error: Tests timeout
# Aumentar timeout en playwright.config.js
```

**Artillery**
```bash
# Error: Command not found
npm install -g artillery

# Error: Connection refused
# Verificar que el sitio esté disponible
curl -I https://dev.cnnchile.com
```

### Variables de Entorno Requeridas

```bash
# AWS
export AWS_PROFILE=cnn-chile
export AWS_REGION=us-east-1

# Testing
export BASE_URL=https://dev.cnnchile.com
export ENVIRONMENT=dev
export NODE_ENV=test

# Opcional
export CI=true  # Para CI/CD
export RUN_LOAD_TESTS=false  # Deshabilitar en local
```

## 🔄 Integración CI/CD

### GitHub Actions
```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Tests
        run: ./scripts/run-tests.sh --all-tests
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Pipeline de Despliegue
1. **Commit** → Trigger automático
2. **Test Suite** → Validación completa
3. **Security Scan** → Verificación seguridad  
4. **Performance Test** → Validación carga
5. **Deploy Staging** → Si tests pasan
6. **E2E Production** → Smoke tests
7. **Deploy Production** → Aprobación manual

## 📚 Recursos Adicionales

- [Terraform Testing](https://www.terraform.io/docs/language/modules/testing-experiment.html)
- [Kubernetes Testing](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-application-introspection/)
- [Playwright Documentation](https://playwright.dev/)
- [Artillery Documentation](https://artillery.io/docs/)
- [Jest Testing Framework](https://jestjs.io/docs/getting-started)

## 🆘 Soporte

Para problemas con las pruebas:
1. Revisar logs en `test-results/`
2. Verificar prerrequisitos con `./scripts/run-tests.sh --help`
3. Consultar documentación técnica en `docs/`
4. Contactar al equipo DevOps

---

**Última actualización:** Diciembre 2024  
**Versión:** 1.0.0
