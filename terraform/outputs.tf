# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = aws_subnet.database[*].id
}

# EKS Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "dynamodb_users_table_name" {
  description = "DynamoDB users table name"
  value       = aws_dynamodb_table.users.name
}

output "dynamodb_sessions_table_name" {
  description = "DynamoDB sessions table name"
  value       = aws_dynamodb_table.sessions.name
}

output "dynamodb_subscriptions_table_name" {
  description = "DynamoDB subscriptions table name"
  value       = aws_dynamodb_table.subscriptions.name
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

# Lambda Outputs
output "notification_lambda_arn" {
  description = "Notification Lambda function ARN"
  value       = aws_lambda_function.notification_service.arn
}

output "event_processor_lambda_arn" {
  description = "Event processor Lambda function ARN"
  value       = aws_lambda_function.event_processor.arn
}

# CloudFront Outputs
output "static_distribution_id" {
  description = "CloudFront static distribution ID"
  value       = aws_cloudfront_distribution.static_distribution.id
}

output "static_distribution_domain_name" {
  description = "CloudFront static distribution domain name"
  value       = aws_cloudfront_distribution.static_distribution.domain_name
}

output "media_distribution_id" {
  description = "CloudFront media distribution ID"
  value       = aws_cloudfront_distribution.media_distribution.id
}

output "media_distribution_domain_name" {
  description = "CloudFront media distribution domain name"
  value       = aws_cloudfront_distribution.media_distribution.domain_name
}

# S3 Outputs
output "media_content_bucket_name" {
  description = "S3 media content bucket name"
  value       = aws_s3_bucket.media_content.id
}

output "static_content_bucket_name" {
  description = "S3 static content bucket name"
  value       = aws_s3_bucket.static_content.id
}

output "live_streaming_bucket_name" {
  description = "S3 live streaming bucket name"
  value       = aws_s3_bucket.live_streaming.id
}

# ALB Outputs
output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Application Load Balancer zone ID"
  value       = aws_lb.main.zone_id
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.web_client.id
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = aws_cognito_identity_pool.main.id
}

# Security Outputs
output "cdn_waf_arn" {
  description = "CloudFront WAF ARN"
  value       = aws_wafv2_web_acl.cdn_waf.arn
}

output "api_waf_arn" {
  description = "API Gateway WAF ARN"
  value       = aws_wafv2_web_acl.api_waf.arn
}

# MediaStore Outputs
output "mediastore_container_name" {
  description = "MediaStore container name"
  value       = aws_media_store_container.live_streaming.name
}

output "mediastore_endpoint" {
  description = "MediaStore container endpoint"
  value       = aws_media_store_container.live_streaming.endpoint
}

# SNS Outputs
output "push_notifications_topic_arn" {
  description = "Push notifications SNS topic ARN"
  value       = aws_sns_topic.push_notifications.arn
}

output "alerts_topic_arn" {
  description = "Alerts SNS topic ARN"
  value       = aws_sns_topic.alerts.arn
}

# Secrets Manager Outputs
output "db_secret_arn" {
  description = "Database credentials secret ARN"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "redis_secret_arn" {
  description = "Redis credentials secret ARN"
  value       = aws_secretsmanager_secret.redis_auth.arn
}
