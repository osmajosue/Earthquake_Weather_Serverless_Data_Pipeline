provider "aws" {
  region = var.aws_region
}

# S3 Buckets
resource "aws_s3_bucket" "raw_data" {
  bucket        = "${var.project_prefix}-raw-data"
  force_destroy = true
}

resource "aws_s3_bucket" "processed_data" {
  bucket        = "${var.project_prefix}-processed-data"
  force_destroy = true
}

resource "aws_s3_bucket" "script_bucket" {
  bucket        = "${var.project_prefix}-scripts"
  force_destroy = true
}

# IAM Role for Lambda Execution
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
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Firehose Write Permissions
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

# IAM Role for Firehose
resource "aws_iam_role" "firehose_eq_role" {
  name = "${var.project_prefix}_firehose_eq_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "firehose.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "firehose_eq_policy" {
  role       = aws_iam_role.firehose_eq_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Firehose for Earthquake data
resource "aws_kinesis_firehose_delivery_stream" "earthquake_stream" {
  name        = "${var.project_prefix}-earthquake-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_eq_role.arn
    bucket_arn         = aws_s3_bucket.raw_data.arn
    prefix             = "earthquakes/"
    buffering_interval = 60
    compression_format = "UNCOMPRESSED"

    cloudwatch_logging_options {
      enabled = false
    }
  }

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Lambda: Fetch Earthquake Data
resource "aws_lambda_function" "fetch_earthquakes" {
  function_name    = "${var.project_prefix}_fetch_earthquakes"
  filename         = "${path.module}/fetch_earthquakes.zip"
  source_code_hash = filebase64sha256("${path.module}/fetch_earthquakes.zip")
  handler          = "fetch_earthquakes.lambda_handler"
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 30

  environment {
    variables = {
      FIREHOSE_NAME = aws_kinesis_firehose_delivery_stream.earthquake_stream.name
    }
  }

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Lambda: Fetch Weather Data (Triggered manually or via event)
resource "aws_lambda_function" "fetch_weather" {
  function_name    = "${var.project_prefix}_fetch_weather"
  filename         = "${path.module}/fetch_weather.zip"
  source_code_hash = filebase64sha256("${path.module}/fetch_weather.zip")
  handler          = "fetch_weather.lambda_handler"
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 60

  environment {
    variables = {
      RAW_BUCKET     = aws_s3_bucket.raw_data.bucket
      QUAKE_PREFIX   = "raw/earthquakes/"
      WEATHER_PREFIX = "raw/weather_data/"
    }
  }

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# EventBridge: Trigger Earthquake Lambda daily
resource "aws_cloudwatch_event_rule" "earthquake_trigger" {
  name                = "${var.project_prefix}_earthquake_trigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "earthquake_lambda_target" {
  rule      = aws_cloudwatch_event_rule.earthquake_trigger.name
  target_id = "FetchEarthquakes"
  arn       = aws_lambda_function.fetch_earthquakes.arn
}

resource "aws_lambda_permission" "allow_earthquake_eventbridge" {
  statement_id  = "AllowEarthquakeFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_earthquakes.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.earthquake_trigger.arn
}

# Glue Catalog Database
resource "aws_glue_catalog_database" "eq_weather_db" {
  name = "${var.project_prefix}_db"
}

# Glue IAM Role
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

# S3 Access Policy for Glue
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
        "${aws_s3_bucket.raw_data.arn}",
        "${aws_s3_bucket.raw_data.arn}/*",
        "${aws_s3_bucket.processed_data.arn}",
        "${aws_s3_bucket.processed_data.arn}/*",
        "${aws_s3_bucket.script_bucket.arn}",
        "${aws_s3_bucket.script_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_s3_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_s3_policy.arn
}

# Glue ETL Job
resource "aws_glue_job" "eq_weather_transform_job" {
  name     = "${var.project_prefix}_transform_job"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.script_bucket.bucket}/glue/glue_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"      = "s3://${aws_s3_bucket.processed_data.bucket}/temp/"
    "--job-language" = "python"
  }

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"
}

# Glue Crawler
resource "aws_glue_crawler" "eq_weather_crawler" {
  name          = "${var.project_prefix}_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.eq_weather_db.name
  table_prefix  = "eq_"

  s3_target {
    path = "s3://${aws_s3_bucket.processed_data.bucket}/"
  }

  configuration = jsonencode({
    Version = 1.0,
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  depends_on = [aws_glue_job.eq_weather_transform_job]

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
