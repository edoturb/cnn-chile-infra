# Lambda Functions Terraform Configuration
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role"

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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Lambda execution policy
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${var.project_name}-lambda-execution-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.sessions.arn,
          aws_dynamodb_table.subscriptions.arn,
          "${aws_dynamodb_table.users.arn}/*",
          "${aws_dynamodb_table.sessions.arn}/*",
          "${aws_dynamodb_table.subscriptions.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "sesv2:SendEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:CreateTopic",
          "sns:Subscribe"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.redis_auth.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections",
          "execute-api:Invoke"
        ]
        Resource = "*"
      }
    ]
  })
}

# Notification Service Lambda
resource "aws_lambda_function" "notification_service" {
  filename      = data.archive_file.notification_service_zip.output_path
  function_name = "${var.project_name}-notification-service"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30
  memory_size   = 256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      AWS_REGION     = data.aws_region.current.name
      FROM_EMAIL     = "noreply@cnnchile.com"
      PUSH_TOPIC_ARN = aws_sns_topic.push_notifications.arn
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "${var.project_name}-notification-service"
  }
}

# Event Processor Lambda
resource "aws_lambda_function" "event_processor" {
  filename      = data.archive_file.event_processor_zip.output_path
  function_name = "${var.project_name}-event-processor"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 60
  memory_size   = 512

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      AWS_REGION              = data.aws_region.current.name
      NOTIFICATION_LAMBDA_ARN = aws_lambda_function.notification_service.arn
      USERS_TABLE             = aws_dynamodb_table.users.name
      ANALYTICS_TABLE         = "cnn-chile-analytics"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "${var.project_name}-event-processor"
  }
}

# Archive files for Lambda deployment
data "archive_file" "notification_service_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/notification-service.zip"
  source_dir  = "${path.module}/../lambda/notification-service"
}

data "archive_file" "event_processor_zip" {
  type        = "zip"
  output_path = "${path.module}/../lambda/event-processor.zip"
  source_dir  = "${path.module}/../lambda/event-processor"
}

# SNS Topic for Push Notifications
resource "aws_sns_topic" "push_notifications" {
  name = "${var.project_name}-push-notifications"
}

# SQS Queue for notification processing
resource "aws_sqs_queue" "notification_queue" {
  name = "${var.project_name}-notification-queue"

  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 3
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "notification_dlq" {
  name                      = "${var.project_name}-notification-dlq"
  message_retention_seconds = 1209600 # 14 days
}

# Lambda triggers
resource "aws_lambda_event_source_mapping" "notification_sqs_trigger" {
  event_source_arn = aws_sqs_queue.notification_queue.arn
  function_name    = aws_lambda_function.notification_service.function_name
  batch_size       = 10
}

# DynamoDB Stream triggers for event processor
resource "aws_lambda_event_source_mapping" "users_stream_trigger" {
  event_source_arn  = aws_dynamodb_table.users.stream_arn
  function_name     = aws_lambda_function.event_processor.function_name
  starting_position = "LATEST"
  batch_size        = 10
}

resource "aws_lambda_event_source_mapping" "subscriptions_stream_trigger" {
  event_source_arn  = aws_dynamodb_table.subscriptions.stream_arn
  function_name     = aws_lambda_function.event_processor.function_name
  starting_position = "LATEST"
  batch_size        = 10
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "notification_service_logs" {
  name              = "/aws/lambda/${aws_lambda_function.notification_service.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "event_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.event_processor.function_name}"
  retention_in_days = 14
}
