terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_dynamodb_table" "timestamps" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

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

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.timestamps.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Lambda/TimestampWriter"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${var.project_name}-lambda-dlq"
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  tags = {
    Name = "${var.project_name}-lambda-dlq"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/${var.lambda_zip_filename}"
}

resource "aws_lambda_function" "timestamp_writer" {
  function_name = "${var.project_name}-timestamp-writer"
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 30

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.timestamps.name
      MAX_RETRIES = "3"
      RETRY_DELAY = "1.0"
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "timestamp_writer" {
  function_name = aws_lambda_function.timestamp_writer.function_name

  maximum_retry_attempts = 2
}

resource "aws_cloudwatch_event_rule" "every_5_minutes" {
  name                = "${var.project_name}-every-5-min"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "target_lambda" {
  rule      = aws_cloudwatch_event_rule.every_5_minutes.name
  target_id = "TimestampWriter"
  arn       = aws_lambda_function.timestamp_writer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.timestamp_writer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_5_minutes.arn
}