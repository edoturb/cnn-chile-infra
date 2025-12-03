# Migración a Nuevo Laboratorio AWS

## Problemas Identificados en Laboratorio Actual

### Permisos Faltantes:
1. **IAM Roles**: No se pueden crear roles (iam:CreateRole)
2. **CloudFront**: No se pueden crear Origin Access Controls
3. **MediaStore**: No se pueden crear containers
4. **X-Ray**: No se pueden crear sampling rules
5. **Certificate Manager**: Problemas con certificados SSL

### Errores Específicos Encontrados:
- Usuario actual: `arn:aws:sts::220017832616:assumed-role/voclabs/user3251212=edua.urbina@duocuc.cl`
- Certificado SSL: `arn:aws:acm:us-east-1:220017832616:certificate/99391835-b547-4e67-9f75-5139740d1110`

## Pasos para Migrar al Nuevo Laboratorio

### 1. Configurar Nuevo Laboratorio
```bash
# En el nuevo laboratorio, configurar AWS CLI
aws configure
# Ingresar las nuevas credenciales del laboratorio extendido
```

### 2. Verificar Permisos
```bash
# Verificar identidad
aws sts get-caller-identity

# Verificar permisos de IAM
aws iam list-roles --max-items 1

# Verificar permisos de CloudFront
aws cloudfront list-distributions --max-items 1
```

### 3. Limpiar Estado Anterior
```bash
cd terraform
# Si hay recursos creados parcialmente, destruir
terraform destroy -var-file="terraform.tfvars" -auto-approve

# Re-inicializar con nuevas credenciales
terraform init -reconfigure
```

### 4. Ejecutar Despliegue Completo
```bash
# Verificar plan
terraform plan -var-file="terraform.tfvars"

# Aplicar cambios
terraform apply -var-file="terraform.tfvars" -auto-approve
```

## Recursos que se Desplegarán

El plan incluye **64 recursos**:
- VPC y networking
- EKS cluster con node groups
- RDS con monitoring
- Lambda functions (Edge y regulares)
- CloudFront distributions
- WAF rules
- Cognito user pools
- S3 buckets
- Load balancers
- Security groups
- IAM roles y policies

## Monitoreo del Despliegue

Una vez iniciado el despliegue, usar:
```bash
# Monitorear EKS
./scripts/monitor-eks.sh

# Verificar estado general
terraform show
```

## Notas Importantes

1. **Tiempo estimado**: 15-20 minutos para despliegue completo
2. **Costos**: Verificar límites del nuevo laboratorio
3. **Certificados**: Verificar que el certificado SSL esté disponible en la nueva cuenta
4. **Dominios**: Ajustar configuración de dominios si es necesario
