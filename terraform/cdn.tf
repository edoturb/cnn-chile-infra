# S3 Buckets for Content Storage
resource "aws_s3_bucket" "media_content" {
  bucket = "${var.project_name}-media-content-${random_id.bucket_suffix.hex}"

  tags = {
    Name    = "${var.project_name}-media-content"
    Purpose = "Media Storage"
  }
}

resource "aws_s3_bucket" "static_content" {
  bucket = "${var.project_name}-static-content-${random_id.bucket_suffix.hex}"

  tags = {
    Name    = "${var.project_name}-static-content"
    Purpose = "Static Assets"
  }
}

resource "aws_s3_bucket" "live_streaming" {
  bucket = "${var.project_name}-live-streaming-${random_id.bucket_suffix.hex}"

  tags = {
    Name    = "${var.project_name}-live-streaming"
    Purpose = "Live Streaming"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket Configurations
resource "aws_s3_bucket_versioning" "media_content_versioning" {
  bucket = aws_s3_bucket.media_content.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media_content_encryption" {
  bucket = aws_s3_bucket.media_content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "media_content_pab" {
  bucket = aws_s3_bucket.media_content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "media_content_cors" {
  bucket = aws_s3_bucket.media_content.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://cnnchile.com", "https://www.cnnchile.com"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# CloudFront Origin Access Control (conditional)
resource "aws_cloudfront_origin_access_control" "media_oac" {
  count                             = var.enable_cloudfront ? 1 : 0
  name                              = "${var.project_name}-media-oac"
  description                       = "OAC for CNN Chile media content"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "static_oac" {
  count                             = var.enable_cloudfront ? 1 : 0
  name                              = "${var.project_name}-static-oac"
  description                       = "OAC for CNN Chile static content"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution for Static Content (conditional)
resource "aws_cloudfront_distribution" "static_distribution" {
  count = var.enable_cloudfront ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.static_content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.static_oac[0].id
    origin_id                = "S3-${aws_s3_bucket.static_content.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CNN Chile Static Content Distribution"
  default_root_object = "index.html"

  # Only use aliases if HTTPS is enabled
  aliases = var.enable_https ? ["static.cnnchile.com"] : []

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_content.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    compress = true

    # Lambda@Edge for geo-restrictions (conditional)
    dynamic "lambda_function_association" {
      for_each = var.enable_lambda_edge ? [1] : []
      content {
        event_type   = "viewer-request"
        lambda_arn   = aws_lambda_function.geo_restriction_edge[0].qualified_arn
        include_body = false
      }
    }
  }

  # Cache behavior for API responses
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.static_content.id}"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Authorization", "CloudFront-Viewer-Country"]

      cookies {
        forward           = "whitelist"
        whitelisted_names = ["session_token", "auth_token"]
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Use ACM certificate if HTTPS is enabled, otherwise use default CloudFront cert
    acm_certificate_arn            = var.enable_https ? aws_acm_certificate.cdn_cert[0].arn : null
    ssl_support_method             = var.enable_https ? "sni-only" : null
    cloudfront_default_certificate = !var.enable_https
  }

  web_acl_id = var.enable_advanced_waf ? aws_wafv2_web_acl.cdn_waf[0].arn : null

  tags = {
    Name = "${var.project_name}-static-distribution"
  }
}

# CloudFront Distribution for Media Content (VoD/Streaming) (conditional)
resource "aws_cloudfront_distribution" "media_distribution" {
  count = var.enable_cloudfront ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.media_content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.media_oac[0].id
    origin_id                = "S3-${aws_s3_bucket.media_content.id}"
  }

  # MediaStore origin for live streaming (conditional)
  dynamic "origin" {
    for_each = var.enable_mediastore ? [1] : []
    content {
      domain_name = aws_media_store_container.live_streaming[0].endpoint
      origin_id   = "MediaStore-LiveStreaming"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CNN Chile Media Content Distribution"

  # Only use aliases if HTTPS is enabled
  aliases = var.enable_https ? ["media.cnnchile.com", "stream.cnnchile.com"] : []

  # Default behavior for VoD content
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.media_content.id}"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Authorization", "CloudFront-Viewer-Country", "User-Agent"]

      cookies {
        forward           = "whitelist"
        whitelisted_names = ["subscription_token", "user_region"]
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    compress = true

    # Lambda@Edge for authentication and geo-restrictions (conditional)
    dynamic "lambda_function_association" {
      for_each = var.enable_lambda_edge ? [1] : []
      content {
        event_type   = "viewer-request"
        lambda_arn   = aws_lambda_function.auth_edge[0].qualified_arn
        include_body = false
      }
    }

    dynamic "lambda_function_association" {
      for_each = var.enable_lambda_edge ? [1] : []
      content {
        event_type   = "origin-response"
        lambda_arn   = aws_lambda_function.security_headers_edge[0].qualified_arn
        include_body = false
      }
    }
  }

  # Cache behavior for live streaming (conditional - only if MediaStore is enabled)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_mediastore ? [1] : []
    content {
      path_pattern     = "/live/*"
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "MediaStore-LiveStreaming"

      forwarded_values {
        query_string = true
        headers      = ["Origin", "Authorization", "CloudFront-Viewer-Country"]

        cookies {
          forward           = "whitelist"
          whitelisted_names = ["subscription_token", "cable_operator_token"]
        }
      }

      viewer_protocol_policy = var.enable_https ? "redirect-to-https" : "allow-all"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 60

      compress = false

      # Authentication for live streaming (conditional)
      dynamic "lambda_function_association" {
        for_each = var.enable_lambda_edge ? [1] : []
        content {
          event_type   = "viewer-request"
          lambda_arn   = aws_lambda_function.live_stream_auth_edge[0].qualified_arn
          include_body = false
        }
      }
    }
  }

  # Cache behavior for HLS/DASH segments (conditional - only if MediaStore is enabled)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_mediastore ? [1] : []
    content {
      path_pattern     = "*.m3u8"
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "MediaStore-LiveStreaming"

      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }

      viewer_protocol_policy = var.enable_https ? "redirect-to-https" : "allow-all"
      min_ttl                = 0
      default_ttl            = 5
      max_ttl                = 10

      compress = false
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.enable_mediastore ? [1] : []
    content {
      path_pattern     = "*.ts"
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "MediaStore-LiveStreaming"

      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }

      viewer_protocol_policy = var.enable_https ? "redirect-to-https" : "allow-all"
      min_ttl                = 0
      default_ttl            = 86400
      max_ttl                = 31536000

      compress = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Use ACM certificate if HTTPS is enabled, otherwise use default CloudFront cert
    acm_certificate_arn            = var.enable_https ? aws_acm_certificate.cdn_cert[0].arn : null
    ssl_support_method             = var.enable_https ? "sni-only" : null
    cloudfront_default_certificate = !var.enable_https
  }

  web_acl_id = var.enable_advanced_waf ? aws_wafv2_web_acl.cdn_waf[0].arn : null

  tags = {
    Name = "${var.project_name}-media-distribution"
  }
}

# AWS MediaStore for Live Streaming (conditional)
resource "aws_media_store_container" "live_streaming" {
  count = var.enable_mediastore ? 1 : 0
  name  = "${replace(var.project_name, "-", "_")}_live_streaming"

  tags = {
    Name = "${var.project_name}-live-streaming"
  }
}

resource "aws_media_store_container_policy" "live_streaming_policy" {
  count          = var.enable_mediastore ? 1 : 0
  container_name = aws_media_store_container.live_streaming[0].name

  # Note: This policy allows public read access for live streaming content
  # In production, consider restricting access with:
  # - CloudFront Origin Access Identity
  # - Signed URLs with time-limited access
  # - IP-based restrictions
  # - Referrer-based restrictions
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadOverHTTPS"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "mediastore:GetObject",
          "mediastore:DescribeObject"
        ]
        Resource = "${aws_media_store_container.live_streaming[0].arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ]
  })
}

# ACM Certificate for CloudFront (conditional)
resource "aws_acm_certificate" "cdn_cert" {
  count       = var.enable_https && var.enable_cloudfront ? 1 : 0
  provider    = aws.us_east_1 # CloudFront requires certificates in us-east-1
  domain_name = "cnnchile.com"

  subject_alternative_names = [
    "*.cnnchile.com",
    "www.cnnchile.com",
    "static.cnnchile.com",
    "media.cnnchile.com",
    "stream.cnnchile.com"
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cdn-certificate"
  }
}

# Provider for us-east-1 (required for CloudFront certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
