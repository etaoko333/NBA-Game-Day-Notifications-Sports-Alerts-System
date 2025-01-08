# Declare the variable for API Key
variable "nba_api_key" {
  description = "The API key for the NBA data"
  type        = string
  sensitive   = true  # Mark it as sensitive to prevent it from being exposed in logs
}

provider "aws" {
  region = "us-west-1" # Change to your preferred region
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "nba-game-updates-bucket"
  acl    = "private"
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "nba_game_updates.zip"
  source = "nba_game_updates.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "nba_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_sns_topic" "nba_updates_topic" {
  name = "nba-game-updates-topic"
}

resource "aws_lambda_function" "nba_game_updates" {
  function_name = "NBA_Game_Updates"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9" # Update based on your Python version
  timeout       = 30

  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key           = aws_s3_object.lambda_code.key

  environment {
    variables = {
      NBA_API_KEY   = var.nba_api_key  # Passing the API key as an environment variable
      SNS_TOPIC_ARN = aws_sns_topic.nba_updates_topic.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule_rule" {
  name                = "NBA_Game_Updates_Schedule"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule_rule.name
  target_id = "NBA_Game_Updates"
  arn       = aws_lambda_function.nba_game_updates.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nba_game_updates.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule_rule.arn
}
