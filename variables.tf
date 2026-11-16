variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Lowercase name used in AWS resource names."
  type        = string
  default     = "microbiome-explorer"
}

variable "image_tag" {
  description = "Container image tag already pushed to the ECR repository."
  type        = string
  default     = "latest"
}

variable "desired_count" {
  description = "Number of running Shiny tasks. Set to zero while preparing the first image."
  type        = number
  default     = 1
}
