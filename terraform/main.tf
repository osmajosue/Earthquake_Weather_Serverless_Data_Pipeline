provider "aws" {
  region = var.aws_region
}

# S3 Buckets
resource "aws_s3_bucket" "raw_data" {
  bucket        = "${var.bucket_prefix}-raw-data"
  force_destroy = true
}

resource "aws_s3_bucket" "processed_data" {
  bucket        = "${var.bucket_prefix}-processed-data"
  force_destroy = true
}

resource "aws_s3_bucket" "script_bucket" {
  bucket        = "${var.bucket_prefix}-scripts"
  force_destroy = true
}

# Upload transformation_job.py script to the scripts bucket
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.script_bucket.bucket
  key    = "glue/transformation_job.py"
  source = "${path.module}/transformation_job.py"
  etag   = filemd5("${path.module}/transformation_job.py")

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
  }
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

# Extra policy for fetch_weather to List + Read S3 (for reading quake files)
resource "aws_iam_policy" "lambda_s3_access_policy" {
  name = "${var.project_prefix}_lambda_s3_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.raw_data.arn}",
          "${aws_s3_bucket.raw_data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_s3_access_policy.arn
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
  timeout          = 120

  environment {
    variables = {
      RAW_BUCKET     = aws_s3_bucket.raw_data.bucket
      QUAKE_PREFIX   = "earthquakes/"
      WEATHER_PREFIX = "weather_data/"
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
    Statement = [

      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.raw_data.arn}",
          "${aws_s3_bucket.raw_data.arn}/*",
          "${aws_s3_bucket.processed_data.arn}",
          "${aws_s3_bucket.processed_data.arn}/*",
          "${aws_s3_bucket.script_bucket.arn}",
          "${aws_s3_bucket.script_bucket.arn}/*",
          "${aws_s3_bucket.gold_data.arn}",
          "${aws_s3_bucket.gold_data.arn}/*"
        ]
      },

      {
        Effect = "Allow",
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ],
        Resource = "*"
      },

      {
        Effect = "Allow",
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetPartition",
          "glue:BatchGetPartition"
        ],
        Resource = "*"
      }
    ]
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
    script_location = "s3://${aws_s3_bucket.script_bucket.bucket}/glue/transformation_job.py"
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

# Gold/Semantic Layer S3 Bucket (for Iceberg)
resource "aws_s3_bucket" "gold_data" {
  bucket        = "${var.bucket_prefix}-gold-data"
  force_destroy = true
  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Glue Workflow
resource "aws_glue_workflow" "eq_weather_workflow" {
  name        = "${var.project_prefix}_workflow"
  description = "Workflow for earthquake + weather data pipeline"
  tags = {
    Project     = var.project_prefix
    Environment = "dev"
  }
}

resource "aws_s3_object" "quality_check_script" {
  bucket = aws_s3_bucket.script_bucket.bucket
  key    = "glue/quality_check.py"
  source = "${path.module}/quality_check.py"
  etag   = filemd5("${path.module}/quality_check.py")
  tags = {
    Project     = var.project_prefix
    Environment = "dev"
  }
}

resource "aws_glue_job" "quality_check_job" {
  name     = "${var.project_prefix}_quality_check"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.script_bucket.bucket}/glue/quality_check.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"                 = "s3://${aws_s3_bucket.processed_data.bucket}/temp/"
    "--job-language"            = "python"
    "--enable-glue-datacatalog" = "true"
  }

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Upload Iceberg write script to S3
resource "aws_s3_object" "write_to_gold_script" {
  bucket = aws_s3_bucket.script_bucket.bucket
  key    = "glue/write_to_gold.py"
  source = "${path.module}/write_to_gold.py"
  etag   = filemd5("${path.module}/write_to_gold.py")

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
  }
}

# Glue Job to append to Iceberg gold table
resource "aws_glue_job" "write_to_gold_job" {
  name     = "${var.project_prefix}_write_to_gold"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.script_bucket.bucket}/glue/write_to_gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"                 = "s3://${aws_s3_bucket.gold_data.bucket}/temp/"
    "--job-language"            = "python"
    "--enable-glue-datacatalog" = "true"
    "--enable-iceberg"          = "true"
    "--datalake-formats"        = "iceberg"
    "--iceberg.warehouse"       = "s3://${aws_s3_bucket.gold_data.bucket}/"
  }

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Trigger: Start Glue Transform Job (initial step in workflow)
resource "aws_glue_trigger" "transform_trigger" {
  name          = "${var.project_prefix}_transform_trigger"
  type          = "ON_DEMAND"
  workflow_name = aws_glue_workflow.eq_weather_workflow.name

  actions {
    job_name = aws_glue_job.eq_weather_transform_job.name
  }
}

# Trigger: Run crawler after transform job completes
resource "aws_glue_trigger" "crawler_trigger" {
  name          = "${var.project_prefix}_crawler_trigger"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.eq_weather_workflow.name

  predicate {
    conditions {
      logical_operator = "EQUALS"
      job_name         = aws_glue_job.eq_weather_transform_job.name
      state            = "SUCCEEDED"
    }
  }

  actions {
    crawler_name = aws_glue_crawler.eq_weather_crawler.name
  }
}

# Trigger: Run quality check after crawler completes
resource "aws_glue_trigger" "quality_check_trigger" {
  name          = "${var.project_prefix}_quality_check_trigger"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.eq_weather_workflow.name

  predicate {
    conditions {
      logical_operator = "EQUALS"
      crawler_name     = aws_glue_crawler.eq_weather_crawler.name
      crawl_state      = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.quality_check_job.name
  }
}

# Trigger: Run write-to-gold job after quality check job succeeds
resource "aws_glue_trigger" "write_to_gold_trigger" {
  name          = "${var.project_prefix}_write_to_gold_trigger"
  type          = "CONDITIONAL"
  workflow_name = aws_glue_workflow.eq_weather_workflow.name
  predicate {
    conditions {
      logical_operator = "EQUALS"
      job_name         = aws_glue_job.quality_check_job.name
      state            = "SUCCEEDED"
    }
  }

  actions {
    job_name = aws_glue_job.write_to_gold_job.name
  }
}

# Provide Athena workgroup and Bucket for storing query results
resource "aws_athena_workgroup" "eq_weather_workgroup" {
  name = "${var.project_prefix}_athena_workgroup"

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.processed_data.bucket}/athena-results/"
    }
  }

  tags = {
    Project     = var.project_prefix
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

