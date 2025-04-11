variable "project_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "nba-pipeline"
}

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}