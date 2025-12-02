# Análisis de Costos - CNN Chile Infrastructure

## Resumen Ejecutivo

Este análisis presenta la estimación de costos mensual y anual para la infraestructura de CNN Chile en AWS, considerando diferentes niveles de tráfico y uso.

### Costos Totales Estimados
- **Desarrollo/Staging**: $1,250 - $1,800 USD/mes
- **Producción (Baseline)**: $3,500 - $5,200 USD/mes
- **Producción (Peak Load)**: $8,000 - $12,000 USD/mes

## Desglose Detallado por Servicio

### 1. Compute Services

#### Amazon EKS
| Componente | Configuración | Costo Base | Costo Peak | Notas |
|------------|---------------|------------|------------|--------|
| EKS Control Plane | 1 cluster | $73/mes | $73/mes | Precio fijo |
| Worker Nodes (t3.large) | 3-5 instancias | $300-500/mes | $600-1000/mes | Auto-scaling |
| Worker Nodes (t3.xlarge) | 0-10 instancias | $0-800/mes | $1600-2000/mes | Peak traffic |
| **Total EKS** | | **$373-1373/mes** | **$2273-3073/mes** | |

#### AWS Lambda
| Función | Invocaciones/mes | Duración Promedio | Costo Estimado |
|---------|------------------|-------------------|-----------------|
| Notification Service | 1M | 2s | $25/mes |
| Event Processor | 500K | 5s | $30/mes |
| Cognito Triggers | 100K | 1s | $5/mes |
| Lambda@Edge | 10M | 50ms | $15/mes |
| **Total Lambda** | | | **$75/mes** |

### 2. Database Services

#### Amazon RDS (PostgreSQL)
| Configuración | Desarrollo | Producción | Peak Load |
|---------------|------------|------------|-----------|
| Instancia | db.t3.micro | db.r5.large | db.r5.2xlarge |
| Multi-AZ | No | Sí | Sí |
| Storage (GP2) | 20GB | 100GB | 500GB |
| Backup Storage | 20GB | 100GB | 500GB |
| **Costo Mensual** | **$25** | **$450** | **$900** |

#### Amazon DynamoDB
| Tabla | Read Units | Write Units | Storage | Costo Mensual |
|-------|------------|-------------|---------|---------------|
| Users | 1000 RCU | 100 WCU | 50GB | $150 |
| Sessions | 2000 RCU | 500 WCU | 20GB | $200 |
| Subscriptions | 500 RCU | 50 WCU | 10GB | $75 |
| Analytics | 100 RCU | 1000 WCU | 100GB | $125 |
| Content | 5000 RCU | 200 WCU | 200GB | $350 |
| **Total DynamoDB** | | | | **$900/mes** |

#### ElastiCache (Redis)
| Configuración | Desarrollo | Producción | Peak Load |
|---------------|------------|------------|-----------|
| Node Type | cache.t3.micro | cache.r6g.large | cache.r6g.2xlarge |
| Número de Nodos | 1 | 2 | 4 |
| **Costo Mensual** | **$15** | **$200** | **$800** |

### 3. Storage Services

#### Amazon S3
| Bucket | Propósito | Storage | Requests | Transfer | Costo Mensual |
|--------|-----------|---------|----------|----------|---------------|
| Media Content | Videos/Imágenes | 5TB | 10M GET | 1TB | $150 |
| Static Content | Assets Web | 100GB | 50M GET | 2TB | $75 |
| Live Streaming | Streaming Temporal | 500GB | 1M GET/PUT | 5TB | $200 |
| Backups | Respaldos | 1TB | 1K | 10GB | $25 |
| **Total S3** | | | | | **$450/mes** |

#### AWS MediaStore
| Configuración | Storage | Requests | Transfer Out | Costo Mensual |
|---------------|---------|----------|--------------|---------------|
| Live Streaming Container | 100GB | 1M | 10TB | $500 |

### 4. Content Delivery Network

#### Amazon CloudFront
| Distribución | Requests/mes | Data Transfer | Costo Mensual |
|--------------|--------------|---------------|---------------|
| Static Distribution | 100M | 2TB | $100 |
| Media Distribution | 50M | 10TB | $800 |
| **Total CloudFront** | | | **$900/mes** |

### 5. Security Services

#### AWS WAF
| Componente | Configuración | Costo Mensual |
|------------|---------------|---------------|
| Web ACLs | 2 ACLs | $2 |
| Rules | 20 rules | $20 |
| Requests | 100M requests | $60 |
| **Total WAF** | | **$82/mes** |

#### AWS Cognito
| Componente | Usuarios Activos | Costo Mensual |
|------------|------------------|---------------|
| User Pool | 50,000 MAU | $275 |
| Identity Pool | Incluido | $0 |
| **Total Cognito** | | **$275/mes** |

### 6. Monitoring & Logging

#### Amazon CloudWatch
| Componente | Configuración | Costo Mensual |
|------------|---------------|---------------|
| Metrics | 1000 custom metrics | $30 |
| Logs | 100GB ingestion | $50 |
| Dashboards | 10 dashboards | $30 |
| Alarms | 50 alarms | $5 |
| **Total CloudWatch** | | **$115/mes** |

#### AWS X-Ray
| Componente | Traces/mes | Costo Mensual |
|------------|------------|---------------|
| Traces Recorded | 1M | $5 |
| Traces Retrieved | 100K | $0.50 |
| **Total X-Ray** | | **$5.50/mes** |

### 7. Networking

#### Data Transfer & NAT Gateway
| Componente | Configuración | Costo Mensual |
|------------|---------------|---------------|
| NAT Gateway | 3 gateways | $135 |
| Data Transfer | 5TB out | $450 |
| **Total Networking** | | **$585/mes** |

### 8. External Services

#### Stripe
| Transacciones | Volumen Mensual | Tarifa | Costo Mensual |
|---------------|-----------------|--------|---------------|
| Suscripciones | $100,000 | 2.9% + $0.30 | $3,200 |
| Pagos Únicos | $20,000 | 2.9% + $0.30 | $680 |
| **Total Stripe** | | | **$3,880/mes** |

## Resumen por Ambiente

### Desarrollo/Staging
| Categoría | Costo Mensual | Porcentaje |
|-----------|---------------|------------|
| Compute | $450 | 36% |
| Databases | $140 | 11% |
| Storage | $200 | 16% |
| CDN | $100 | 8% |
| Security | $150 | 12% |
| Monitoring | $50 | 4% |
| Networking | $160 | 13% |
| **Total** | **$1,250** | **100%** |

### Producción (Baseline)
| Categoría | Costo Mensual | Porcentaje |
|-----------|---------------|------------|
| Compute | $1,448 | 28% |
| Databases | $1,550 | 30% |
| Storage | $950 | 18% |
| CDN | $900 | 17% |
| Security | $357 | 7% |
| Monitoring | $120 | 2% |
| Networking | $585 | 11% |
| External (Stripe) | $3,880 | 75%* |
| **Total (Sin Stripe)** | **$5,200** | **100%** |
| **Total (Con Stripe)** | **$9,080** | **175%** |

*Stripe se considera costo de revenue-sharing, no infraestructura

### Producción (Peak Load)
| Categoría | Costo Mensual | Porcentaje |
|-----------|---------------|------------|
| Compute | $3,148 | 26% |
| Databases | $2,600 | 22% |
| Storage | $1,400 | 12% |
| CDN | $1,800 | 15% |
| Security | $500 | 4% |
| Monitoring | $200 | 2% |
| Networking | $1,200 | 10% |
| External (Stripe) | $7,760 | 65%* |
| **Total (Sin Stripe)** | **$12,000** | **100%** |
| **Total (Con Stripe)** | **$19,760** | **165%** |

## Estrategias de Optimización de Costos

### Immediate (0-3 meses)
1. **Reserved Instances**
   - RDS: 30% de ahorro ($135/mes)
   - ElastiCache: 35% de ahorro ($70/mes)
   - **Ahorro Total**: $205/mes

2. **S3 Intelligent Tiering**
   - Ahorro estimado: 20-40% en storage ($90-180/mes)

3. **CloudWatch Logs Retention**
   - Configurar retención a 30 días
   - **Ahorro**: $25/mes

### Medium Term (3-6 meses)
1. **Spot Instances para Workloads Tolerantes**
   - 60% de descuento en nodos no-críticos
   - **Ahorro**: $300-600/mes

2. **CDN Cache Optimization**
   - Aumentar TTL para contenido estático
   - **Ahorro**: $100-200/mes

3. **DynamoDB On-Demand → Provisioned**
   - Para tablas con patrones predecibles
   - **Ahorro**: $150-300/mes

### Long Term (6-12 meses)
1. **Savings Plans**
   - Compute Savings Plans: 15-20% adicional
   - **Ahorro**: $200-400/mes

2. **Multi-Region Optimization**
   - Ubicar recursos cerca de usuarios
   - Reducir data transfer costs
   - **Ahorro**: $150-300/mes

## Escalado de Costos por Tráfico

### Métricas de Escalado
| Usuarios Concurrentes | Requests/min | Costo Mensual |
|----------------------|--------------|---------------|
| 1,000 | 10K | $3,500 |
| 5,000 | 50K | $5,200 |
| 10,000 | 100K | $7,500 |
| 25,000 | 250K | $12,000 |
| 50,000 | 500K | $22,000 |

### Break-even Analysis
- **Suscriptores necesarios (Plan $9.99/mes)**: 520-1,200 usuarios
- **Ingresos publicitarios necesarios**: $2,000-6,000/mes
- **CAC máximo recomendado**: $15-25 por usuario

## Recomendaciones

### Prioridad Alta
1. Implementar Reserved Instances desde el primer mes
2. Configurar CloudWatch billing alerts
3. Usar S3 Intelligent Tiering para todos los buckets
4. Implementar auto-scaling agresivo para EKS nodes

### Prioridad Media
1. Evaluar Spot Instances para cargas no-críticas
2. Optimizar consultas DynamoDB para reducir RCU/WCU
3. Implementar compresión en CloudFront
4. Revisar retention policies mensualmente

### Prioridad Baja
1. Considerar migración a Graviton instances (ARM)
2. Evaluar alternativas open-source para monitoreo
3. Implementar data lifecycle policies en S3

## Monitoring y Alertas de Costos

### Alerts Recomendadas
- Costo mensual > $6,000 USD
- Incremento semanal > 20%
- Data transfer > 10TB/mes
- Lambda invocations > 5M/mes

### Reportes Mensuales
1. Cost and Usage Report analysis
2. Right-sizing recommendations
3. Unused resources audit
4. Reserved Instance utilization

## Conclusiones

La infraestructura de CNN Chile está diseñada para ser:
- **Escalable**: Costos crecen proporcionalmente con el uso
- **Optimizable**: Múltiples estrategias de optimización disponibles
- **Predecible**: Costos base estables con picos controlados
- **ROI Positivo**: Break-even alcanzable con 520+ suscriptores mensuales

El modelo de pricing híbrido (fixed + variable) permite un crecimiento sostenible mientras mantiene costos operacionales predecibles.
