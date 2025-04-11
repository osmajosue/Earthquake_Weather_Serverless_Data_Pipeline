output "raw_bucket_name" {
  description = "S3 bucket for raw data"
  value       = aws_s3_bucket.nba_raw.bucket
}

output "processed_bucket_name" {
  description = "S3 bucket for processed data"
  value       = aws_s3_bucket.nba_processed.bucket
}

output "lambda_function_name" {
  description = "Name of the NBA ingestion Lambda function"
  value       = aws_lambda_function.nba_ingestor.function_name
}
