# CNN Chile - Infraestructura Digital Moderna

## Descripción del Proyecto

Implementación de una plataforma tecnológica moderna para CNN Chile que integra sitio web, aplicación móvil, gestión de contenido, streaming en vivo, y sistema de suscripciones para audiencias nacionales e internacionales.

## Arquitectura de la Solución

### Componentes Principales

- **Frontend**: Sitio web multiplataforma (cnnchile.com) y aplicación móvil
- **Backend**: Microservicios containerizados en Kubernetes
- **Serverless**: Funciones Lambda para procesamiento de eventos y notificaciones
- **Bases de Datos**: 
  - RDS (PostgreSQL) para datos financieros y backoffice
  - DynamoDB para datos de usuarios y sesiones
- **CDN**: CloudFront para contenido estático y streaming
- **Streaming**: Integración con servicios de VoD y Live Streaming
- **Seguridad**: WAF, OAuth2/JWT, IAM roles, cifrado TLS/SSL

### Stack Tecnológico

- **Cloud Provider**: AWS
- **Infrastructure as Code**: Terraform
- **Orchestration**: Amazon EKS (Kubernetes)
- **Serverless**: AWS Lambda
- **API Gateway**: AWS API Gateway
- **Databases**: Amazon RDS, DynamoDB
- **CDN**: Amazon CloudFront
- **Monitoring**: CloudWatch, AWS X-Ray
- **Security**: AWS WAF, AWS Cognito

## Estructura del Proyecto

```
├── terraform/          # Configuración de infraestructura
├── kubernetes/          # Manifiestos de Kubernetes
├── lambda/             # Funciones serverless
├── microservices/      # Código de microservicios
├── docs/               # Documentación y diagramas
└── scripts/            # Scripts de despliegue automatizado
```

## Funcionalidades Clave

### Para Usuarios en Chile
- Validación de login con cableoperadores
- Acceso a señal en vivo
- Consumo de noticias y contenido

### Para Usuarios Fuera de Chile
- Registro de usuarios sin cableoperador
- Sistema de suscripciones (mensual/anual)
- Procesamiento de pagos con Stripe
- Acceso a contenido premium

### Características Técnicas
- Escalabilidad automática para eventos críticos
- Cumplimiento de normativas de protección de datos (Chile, EEUU, UE)
- Sistema MAM para gestión de medios
- Notificaciones multi-canal (email, websocket, push)
- Alta disponibilidad y tolerancia a fallos

## Requisitos Previos

- AWS CLI configurado
- Terraform >= 1.0
- kubectl
- Docker

## Despliegue

Ver [Guía de Despliegue](docs/deployment-guide.md) para instrucciones detalladas.

## Monitoreo y Mantenimiento

La solución incluye monitoreo en tiempo real y trazabilidad distribuida para garantizar la observabilidad completa del sistema.