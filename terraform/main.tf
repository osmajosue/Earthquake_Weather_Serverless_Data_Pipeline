
provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "raw_data" {
  bucket = "${var.project_prefix}-raw-data"
  force_destroy = true
}

resource "aws_s3_bucket" "processed_data" {
  bucket = "${var.project_prefix}-processed-data"
  force_destroy = true
}

resource "aws_s3_bucket" "script_bucket" {
  bucket = "${var.project_prefix}-scripts"
  force_destroy = true
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_prefix}_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Principal = { Service = "lambda.amazonaws.com" },
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_firehose_policy" {
  name = "${var.project_prefix}_lambda_firehose_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_firehose_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_firehose_policy.arn
}

resource "aws_iam_role" "firehose_role" {
  name = "${var.project_prefix}_firehose_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "firehose.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_policy" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_kinesis_firehose_delivery_stream" "nba_stream" {
  name        = "${var.project_prefix}-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.raw_data.arn
    buffering_interval = 60
    compression_format = "UNCOMPRESSED"

    cloudwatch_logging_options {
      enabled = false
    }
  }
}

resource "aws_lambda_function" "nba_lambda" {
  function_name = "${var.project_prefix}_fetch_nba_data"
  filename      = "${path.module}/lambda.zip"
  handler       = "handler.lambda_handler"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 30
  environment {
    variables = {
      FIREHOSE_NAME = aws_kinesis_firehose_delivery_stream.nba_stream.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.project_prefix}_daily_trigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "NBAIngestLambda"
  arn       = aws_lambda_function.nba_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.nba_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

resource "aws_glue_catalog_database" "nba_db" {
  name = "${var.project_prefix}_db"
}

resource "aws_iam_role" "glue_role" {
  name = "${var.project_prefix}_glue_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "glue.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_policy" "glue_s3_policy" {
  name = "${var.project_prefix}_glue_s3_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"
      ],
      Resource = [
        "${aws_s3_bucket.raw_data.arn}/*",
        "${aws_s3_bucket.processed_data.arn}/*",
        "${aws_s3_bucket.script_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_s3_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_s3_policy.arn
}

resource "aws_glue_job" "nba_transform" {
  name     = "${var.project_prefix}_transform_job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.script_bucket.bucket}/glue/glue_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"       = "s3://${aws_s3_bucket.processed_data.bucket}/temp/"
    "--job-language"  = "python"
  }

  glue_version        = "4.0"
  number_of_workers   = 2
  worker_type         = "G.1X"
}

resource "aws_glue_crawler" "nba_crawler" {
  name          = "${var.project_prefix}_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.nba_db.name
  table_prefix  = "nba_"
  s3_target {
    path = "s3://${aws_s3_bucket.processed_data.bucket}/"
  }

  configuration = jsonencode({
    Version = 1.0,
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  depends_on = [aws_glue_job.nba_transform]
  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
