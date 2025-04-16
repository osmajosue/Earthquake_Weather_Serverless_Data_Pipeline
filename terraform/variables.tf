variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefix for naming AWS resources"
  type        = string
  default     = "eq_weather_pipeline"
}

variable "bucket_prefix" {
  description = "Prefix for naming AWS resources"
  type        = string
  default     = "eq-weather"
}
