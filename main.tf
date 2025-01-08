provider "aws" {
  region = var.aws_region
}

# Declare the variable for the API Key
variable "nba_api_key" {
  description = "The API key for the NBA data"
  type        = string
  sensitive   = true
}

variable "email_address" {
  description = "The email address for SNS subscription"
  type        = string
}

variable "phone_number" {
  description = "The phone number for SNS subscription"
  type        = string
}

resource "aws_sns_topic" "gd_topic" {
  name = "gd_topic"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name   = "sns_publish_policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect   = "Allow",
          Action   = "sns:Publish",
          Resource = aws_sns_topic.gd_topic.arn
        }
      ]
    })
  }
}

resource "aws_lambda_function" "gd_notifications" {
  function_name = "gd_notifications"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.8"
  handler       = "gd_notifications.lambda_handler"
  filename      = "path/to/your/lambda/code.zip"

  environment {
    variables = {
      NBA_API_KEY   = var.nba_api_key
      SNS_TOPIC_ARN = aws_sns_topic.gd_topic.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "gd_notifications_schedule" {
  name                = "gd_notifications_schedule"
  schedule_expression = "cron(0 9 * * ? *)" # Every day at 9:00 AM UTC
}

resource "aws_cloudwatch_event_target" "gd_notifications_target" {
  rule      = aws_cloudwatch_event_rule.gd_notifications_schedule.name
  target_id = "gd_notifications_target"
  arn       = aws_lambda_function.gd_notifications.arn
}

resource "aws_lambda_permission" "allow_eventbridge_invocation" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gd_notifications.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.gd_notifications_schedule.arn
}

resource "aws_sns_topic_subscription" "email_subscription" {
  protocol = "email"
  endpoint = var.email_address
  topic_arn = aws_sns_topic.gd_topic.arn
}

resource "aws_sns_topic_subscription" "sms_subscription" {
  protocol = "sms"
  endpoint = var.phone_number
  topic_arn = aws_sns_topic.gd_topic.arn
}
