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

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "media_oac" {
  name                              = "${var.project_name}-media-oac"
  description                       = "OAC for CNN Chile media content"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "static_oac" {
  name                              = "${var.project_name}-static-oac"
  description                       = "OAC for CNN Chile static content"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution for Static Content
resource "aws_cloudfront_distribution" "static_distribution" {
  origin {
    domain_name              = aws_s3_bucket.static_content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.static_oac.id
    origin_id                = "S3-${aws_s3_bucket.static_content.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CNN Chile Static Content Distribution"
  default_root_object = "index.html"

  aliases = ["static.cnnchile.com"]

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

    # Lambda@Edge for geo-restrictions
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.geo_restriction_edge.qualified_arn
      include_body = false
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
    acm_certificate_arn = aws_acm_certificate.cdn_cert.arn
    ssl_support_method  = "sni-only"
  }

  web_acl_id = aws_wafv2_web_acl.cdn_waf.arn

  tags = {
    Name = "${var.project_name}-static-distribution"
  }
}

# CloudFront Distribution for Media Content (VoD/Streaming)
resource "aws_cloudfront_distribution" "media_distribution" {
  origin {
    domain_name              = aws_s3_bucket.media_content.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.media_oac.id
    origin_id                = "S3-${aws_s3_bucket.media_content.id}"
  }

  # MediaStore origin for live streaming
  origin {
    domain_name = aws_media_store_container.live_streaming.endpoint
    origin_id   = "MediaStore-LiveStreaming"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CNN Chile Media Content Distribution"

  aliases = ["media.cnnchile.com", "stream.cnnchile.com"]

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

    # Lambda@Edge for authentication and geo-restrictions
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.auth_edge.qualified_arn
      include_body = false
    }

    lambda_function_association {
      event_type   = "origin-response"
      lambda_arn   = aws_lambda_function.security_headers_edge.qualified_arn
      include_body = false
    }
  }

  # Cache behavior for live streaming
  ordered_cache_behavior {
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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 60

    compress = false

    # Authentication for live streaming
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.live_stream_auth_edge.qualified_arn
      include_body = false
    }
  }

  # Cache behavior for HLS/DASH segments
  ordered_cache_behavior {
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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 5
    max_ttl                = 10

    compress = false
  }

  ordered_cache_behavior {
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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    compress = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cdn_cert.arn
    ssl_support_method  = "sni-only"
  }

  web_acl_id = aws_wafv2_web_acl.cdn_waf.arn

  tags = {
    Name = "${var.project_name}-media-distribution"
  }
}

# AWS MediaStore for Live Streaming
resource "aws_media_store_container" "live_streaming" {
  name = "${replace(var.project_name, "-", "_")}_live_streaming"

  tags = {
    Name = "${var.project_name}-live-streaming"
  }
}

resource "aws_media_store_container_policy" "live_streaming_policy" {
  container_name = aws_media_store_container.live_streaming.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MediaStoreFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.media_live_role.arn
        }
        Action   = "mediastore:*"
        Resource = "*"
      },
      {
        Sid       = "PublicReadOverHTTPS"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "mediastore:GetObject",
          "mediastore:DescribeObject"
        ]
        Resource = "${aws_media_store_container.live_streaming.arn}/*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ]
  })
}

# ACM Certificate for CloudFront
resource "aws_acm_certificate" "cdn_cert" {
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
