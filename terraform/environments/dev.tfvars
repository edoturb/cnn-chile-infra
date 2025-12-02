# Development Environment Variables
# CNN Chile Infrastructure

# General Configuration
project_name = "cnn-chile-dev"
environment  = "dev"
aws_region   = "us-east-1"

# Domain Configuration
domain_name        = "dev.cnnchile.com"
api_domain_name    = "api-dev.cnnchile.com"
cdn_domain_name    = "cdn-dev.cnnchile.com"
streaming_domain_name = "streaming-dev.cnnchile.com"

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

# EKS Configuration
cluster_name    = "cnn-chile-dev-cluster"
node_group_name = "cnn-chile-dev-nodes"
kubernetes_version = "1.28"
eks_node_instance_types = ["t3.medium"]
eks_node_desired_capacity = 2
eks_node_max_capacity = 4
eks_node_min_capacity = 1

# Database Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20
db_max_allocated_storage = 100
db_engine_version = "15.3"
db_backup_retention_period = 7
db_backup_window = "03:00-04:00"
db_maintenance_window = "Sun:04:00-Sun:05:00"
db_multi_az = false

# Cache Configuration
redis_node_type = "cache.t3.micro"
redis_num_cache_nodes = 1
redis_parameter_group_name = "default.redis7"
redis_port = 6379
redis_engine_version = "7.0"

# DynamoDB Configuration
dynamodb_billing_mode = "PAY_PER_REQUEST"

# Lambda Configuration
lambda_runtime = "nodejs18.x"
lambda_timeout = 30
lambda_memory_size = 256

# CloudFront Configuration
cloudfront_price_class = "PriceClass_100"
cloudfront_min_ttl = 0
cloudfront_default_ttl = 86400
cloudfront_max_ttl = 31536000

# MediaStore Configuration
mediastore_container_name = "cnn-chile-dev-live-streaming"

# Cognito Configuration
cognito_user_pool_name = "cnn-chile-dev-users"
cognito_client_name = "cnn-chile-dev-client"

# OAuth Configuration (Development)
facebook_app_id = "dev-facebook-app-id"
google_client_id = "dev-google-client-id.googleusercontent.com"

# Auto Scaling Configuration
enable_autoscaling = true
target_cpu_utilization = 70
target_memory_utilization = 80

# Monitoring Configuration
enable_detailed_monitoring = true
log_retention_days = 30
enable_xray_tracing = true

# Security Configuration
enable_waf = true
enable_shield = false # Advanced Shield not needed for dev
allowed_cidr_blocks = ["0.0.0.0/0"] # Open for development

# Cost Optimization for Development
enable_cost_optimization = true
enable_reserved_instances = false # Not cost-effective for dev
enable_spot_instances = true

# Backup Configuration
enable_automated_backups = true
backup_retention_period = 7

# Tags for Development
additional_tags = {
  Owner       = "DevOps Team"
  CostCenter  = "Engineering"
  Backup      = "Required"
  Monitoring  = "Enabled"
  Compliance  = "Dev"
}
