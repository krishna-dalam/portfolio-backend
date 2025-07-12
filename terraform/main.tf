provider "aws" {
  region = var.region
}

# S3 for maintaining tfstate

resource "aws_s3_bucket" "tfstate" {
  bucket = "tfstate-bucket"
  force_destroy = true
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "contact_form_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "lambda-logs"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ses_send_policy" {
  name = "lambda_ses_send"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "ses:SendEmail",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
data "archive_file" "contact_me_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/contact-me"
  output_path = "${path.module}/contact_me_lambda.zip"
}

resource "aws_lambda_function" "contact_me_lambda" {
  function_name = "contact-me-form-handler"
  filename      = data.archive_file.contact_me_lambda_zip.output_path
  source_code_hash = data.archive_file.contact_me_lambda_zip.output_base64sha256
  handler       = "contact-me-lambda.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      EMAIL_SENDER    = var.email_sender
      EMAIL_RECIPIENT = var.email_recipient
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "contact-me-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["*"]
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_me_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.contact_me_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /contact-me"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

terraform {
  backend "s3" {
    bucket         = "tfstate-bucket"
    key            = "contact-me-form/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}

