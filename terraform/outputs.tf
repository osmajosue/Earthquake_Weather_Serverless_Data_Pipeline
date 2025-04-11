output "raw_data_bucket" {
  description = "S3 bucket for raw NBA data"
  value       = aws_s3_bucket.raw_data.bucket
}

output "processed_data_bucket" {
  description = "S3 bucket for processed NBA data"
  value       = aws_s3_bucket.processed_data.bucket
}

output "scripts_bucket" {
  description = "S3 bucket for Glue PySpark scripts"
  value       = aws_s3_bucket.script_bucket.bucket
}

output "firehose_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.nba_stream.name
}

output "lambda_function_name" {
  description = "Lambda function that fetches NBA data"
  value       = aws_lambda_function.nba_lambda.function_name
}

output "glue_job_name" {
  description = "AWS Glue job for transforming NBA data"
  value       = aws_glue_job.nba_transform.name
}
