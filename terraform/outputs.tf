output "raw_data_bucket" {
  description = "S3 bucket for raw data"
  value       = aws_s3_bucket.raw_data.bucket
}

output "processed_data_bucket" {
  description = "S3 bucket for processed data"
  value       = aws_s3_bucket.processed_data.bucket
}

output "script_bucket" {
  description = "S3 bucket for Glue scripts"
  value       = aws_s3_bucket.script_bucket.bucket
}

output "earthquake_lambda_name" {
  description = "Lambda function for ingesting earthquake data"
  value       = aws_lambda_function.fetch_earthquakes.function_name
}

output "weather_lambda_name" {
  description = "Lambda function for enriching weather data"
  value       = aws_lambda_function.fetch_weather.function_name
}

output "earthquake_firehose_stream" {
  description = "Kinesis Firehose stream name for earthquake data"
  value       = aws_kinesis_firehose_delivery_stream.earthquake_stream.name
}

output "glue_job_name" {
  description = "Glue job for processing earthquake + weather data"
  value       = aws_glue_job.eq_weather_transform_job.name
}

output "glue_crawler_name" {
  description = "Glue crawler to catalog processed data"
  value       = aws_glue_crawler.eq_weather_crawler.name
}
