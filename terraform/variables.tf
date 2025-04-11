variable "project_prefix" {
  description = "Prefix to name and group related resources"
  type        = string
  default     = "nba-pipeline"
}

variable "aws_region" {
  description = "AWS region to deploy the infrastructure"
  type        = string
  default     = "us-east-1"
}