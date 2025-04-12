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

output "games_lambda_name" {
  description = "Lambda function for fetching game data"
  value       = aws_lambda_function.fetch_games.function_name
}

output "stats_lambda_name" {
  description = "Lambda function for fetching player stats"
  value       = aws_lambda_function.fetch_stats.function_name
}

output "games_firehose_stream" {
  description = "Kinesis Firehose for game data"
  value       = aws_kinesis_firehose_delivery_stream.games_stream.name
}

output "stats_firehose_stream" {
  description = "Kinesis Firehose for stats data"
  value       = aws_kinesis_firehose_delivery_stream.stats_stream.name
}

output "glue_job_name" {
  description = "AWS Glue job for transforming NBA data"
  value       = aws_glue_job.nba_transform.name
}
