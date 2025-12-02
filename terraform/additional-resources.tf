# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for EKS Services
resource "aws_lb_target_group" "eks_api" {
  name     = "${var.project_name}-eks-api"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-eks-api-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_api.arn
  }
}

# ALB HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ACM Certificate for ALB
resource "aws_acm_certificate" "main" {
  domain_name       = "api.cnnchile.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "cnnchile.com",
    "www.cnnchile.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

# IAM Role for MediaLive
resource "aws_iam_role" "media_live_role" {
  name = "${var.project_name}-media-live-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "medialive.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-media-live-role"
  }
}

resource "aws_iam_role_policy_attachment" "media_live_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/MediaLiveAccessRole"
  role       = aws_iam_role.media_live_role.name
}

# Lambda@Edge Functions for CloudFront
resource "aws_lambda_function" "geo_restriction_edge" {
  provider      = aws.us_east_1
  filename      = data.archive_file.geo_restriction_edge_zip.output_path
  function_name = "${var.project_name}-geo-restriction-edge"
  role          = aws_iam_role.lambda_edge_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 5
  memory_size   = 128

  publish = true

  tags = {
    Name = "${var.project_name}-geo-restriction-edge"
  }
}

resource "aws_lambda_function" "auth_edge" {
  provider      = aws.us_east_1
  filename      = data.archive_file.auth_edge_zip.output_path
  function_name = "${var.project_name}-auth-edge"
  role          = aws_iam_role.lambda_edge_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 5
  memory_size   = 128

  publish = true

  tags = {
    Name = "${var.project_name}-auth-edge"
  }
}

resource "aws_lambda_function" "security_headers_edge" {
  provider      = aws.us_east_1
  filename      = data.archive_file.security_headers_edge_zip.output_path
  function_name = "${var.project_name}-security-headers-edge"
  role          = aws_iam_role.lambda_edge_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 5
  memory_size   = 128

  publish = true

  tags = {
    Name = "${var.project_name}-security-headers-edge"
  }
}

resource "aws_lambda_function" "live_stream_auth_edge" {
  provider      = aws.us_east_1
  filename      = data.archive_file.live_stream_auth_edge_zip.output_path
  function_name = "${var.project_name}-live-stream-auth-edge"
  role          = aws_iam_role.lambda_edge_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 5
  memory_size   = 128

  publish = true

  tags = {
    Name = "${var.project_name}-live-stream-auth-edge"
  }
}

# IAM Role for Lambda@Edge
resource "aws_iam_role" "lambda_edge_execution_role" {
  provider = aws.us_east_1
  name     = "${var.project_name}-lambda-edge-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic_execution" {
  provider   = aws.us_east_1
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_edge_execution_role.name
}

# Cognito Lambda Functions
resource "aws_lambda_function" "cognito_pre_signup" {
  filename      = data.archive_file.cognito_pre_signup_zip.output_path
  function_name = "${var.project_name}-cognito-pre-signup"
  role          = aws_iam_role.cognito_lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  tags = {
    Name = "${var.project_name}-cognito-pre-signup"
  }
}

resource "aws_lambda_function" "cognito_post_confirmation" {
  filename      = data.archive_file.cognito_post_confirmation_zip.output_path
  function_name = "${var.project_name}-cognito-post-confirmation"
  role          = aws_iam_role.cognito_lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  tags = {
    Name = "${var.project_name}-cognito-post-confirmation"
  }
}

resource "aws_lambda_function" "cognito_pre_auth" {
  filename      = data.archive_file.cognito_pre_auth_zip.output_path
  function_name = "${var.project_name}-cognito-pre-auth"
  role          = aws_iam_role.cognito_lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  tags = {
    Name = "${var.project_name}-cognito-pre-auth"
  }
}

resource "aws_lambda_function" "cognito_post_auth" {
  filename      = data.archive_file.cognito_post_auth_zip.output_path
  function_name = "${var.project_name}-cognito-post-auth"
  role          = aws_iam_role.cognito_lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  tags = {
    Name = "${var.project_name}-cognito-post-auth"
  }
}

resource "aws_lambda_function" "cognito_create_auth_challenge" {
  filename      = data.archive_file.cognito_create_auth_challenge_zip.output_path
  function_name = "${var.project_name}-cognito-create-auth-challenge"
  role          = aws_iam_role.cognito_lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  tags = {
    Name = "${var.project_name}-cognito-create-auth-challenge"
  }
}

resource "aws_lambda_function" "cognito_define_auth_challenge" {
  filename      = data.archive_file.cognito_define_auth_challenge_zip.output_path
  function_name = "${var.project_name}-cognito-define-auth-challenge"
  role          = aws_iam_role.cognito_lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  tags = {
    Name = "${var.project_name}-cognito-define-auth-challenge"
  }
}

resource "aws_lambda_function" "cognito_verify_auth_challenge" {
  filename      = data.archive_file.cognito_verify_auth_challenge_zip.output_path
  function_name = "${var.project_name}-cognito-verify-auth-challenge"
  role          = aws_iam_role.cognito_lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 10

  tags = {
    Name = "${var.project_name}-cognito-verify-auth-challenge"
  }
}

# IAM Role for Cognito Lambda functions
resource "aws_iam_role" "cognito_lambda_execution_role" {
  name = "${var.project_name}-cognito-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cognito_lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.cognito_lambda_execution_role.name
}

# Archive files for Lambda@Edge functions
data "archive_file" "geo_restriction_edge_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/geo-restriction-edge.zip"
  source {
    content  = "exports.handler = async (event) => { return event.Records[0].cf.request; };"
    filename = "index.js"
  }
}

data "archive_file" "auth_edge_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/auth-edge.zip"
  source {
    content  = "exports.handler = async (event) => { return event.Records[0].cf.request; };"
    filename = "index.js"
  }
}

data "archive_file" "security_headers_edge_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/security-headers-edge.zip"
  source {
    content  = "exports.handler = async (event) => { const response = event.Records[0].cf.response; response.headers['strict-transport-security'] = [{key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains'}]; return response; };"
    filename = "index.js"
  }
}

data "archive_file" "live_stream_auth_edge_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/live-stream-auth-edge.zip"
  source {
    content  = "exports.handler = async (event) => { return event.Records[0].cf.request; };"
    filename = "index.js"
  }
}

# Archive files for Cognito Lambda functions
data "archive_file" "cognito_pre_signup_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/cognito-pre-signup.zip"
  source {
    content  = "exports.handler = async (event) => { return event; };"
    filename = "index.js"
  }
}

data "archive_file" "cognito_post_confirmation_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/cognito-post-confirmation.zip"
  source {
    content  = "exports.handler = async (event) => { return event; };"
    filename = "index.js"
  }
}

data "archive_file" "cognito_pre_auth_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/cognito-pre-auth.zip"
  source {
    content  = "exports.handler = async (event) => { return event; };"
    filename = "index.js"
  }
}

data "archive_file" "cognito_post_auth_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/cognito-post-auth.zip"
  source {
    content  = "exports.handler = async (event) => { return event; };"
    filename = "index.js"
  }
}

data "archive_file" "cognito_create_auth_challenge_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/cognito-create-auth-challenge.zip"
  source {
    content  = "exports.handler = async (event) => { return event; };"
    filename = "index.js"
  }
}

data "archive_file" "cognito_define_auth_challenge_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/cognito-define-auth-challenge.zip"
  source {
    content  = "exports.handler = async (event) => { return event; };"
    filename = "index.js"
  }
}

data "archive_file" "cognito_verify_auth_challenge_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/cognito-verify-auth-challenge.zip"
  source {
    content  = "exports.handler = async (event) => { return event; };"
    filename = "index.js"
  }
}
