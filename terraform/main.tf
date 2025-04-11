provider "aws" {
  region = var.aws_region
}

# --- S3 Buckets ---
resource "aws_s3_bucket" "nba_raw" {
  bucket = "${var.project_prefix}-raw-bucket"
}

resource "aws_s3_bucket" "nba_processed" {
  bucket = "${var.project_prefix}-processed-bucket"
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_prefix}_lambda_exec_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# --- Lambda Function ---
resource "aws_lambda_function" "nba_ingestor" {
  function_name = "${var.project_prefix}_nba_ingestor"
  runtime       = "python3.9"
  handler       = "handler.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "${path.module}/lambda.zip"
  timeout       = 60
  memory_size   = 256
  environment {
    variables = {
      RAW_BUCKET_NAME = aws_s3_bucket.nba_raw.bucket
    }
  }
}

# --- EventBridge Schedule for Lambda ---
resource "aws_cloudwatch_event_rule" "every_day" {
  name                = "${var.project_prefix}_daily_trigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_day.name
  target_id = "lambda"
  arn       = aws_lambda_function.nba_ingestor.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nba_ingestor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_day.arn
}

# --- Outputs ---
output "raw_bucket_name" {
  value = aws_s3_bucket.nba_raw.bucket
}

output "processed_bucket_name" {
  value = aws_s3_bucket.nba_processed.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.nba_ingestor.function_name
}