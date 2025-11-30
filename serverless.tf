# Nota: Debes tener un archivo vacío llamado 'lambda_handler.zip' en la raíz 
# de tu proyecto antes de ejecutar, ya que Terraform lo requiere para el hash.

# 1. Rol IAM para que Lambda pueda ejecutarse (Mínimo Privilegio)
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# 2. Función Serverless (AWS Lambda)
resource "aws_lambda_function" "notification_processor" {
  filename      = "lambda_handler.zip" 
  function_name = "${var.project_name}-notification-processor"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  memory_size   = 128
  timeout       = 30

  # Hash para detectar cambios en el archivo zip.
  source_code_hash = filebase64sha256("lambda_handler.zip")
}

# 3. API Gateway (Punto de Entrada HTTP)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-api-gateway"
  protocol_type = "HTTP"
  target        = aws_lambda_function.notification_processor.arn 
}
