variable "region" {
  description = "AWS region for the dev observability resources."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "eventpulse"
}

variable "environment" {
  description = "Environment name used in resource naming."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "abhishek"
}

variable "purpose" {
  description = "Purpose tag value."
  type        = string
  default     = "portfolio-learning"
}

variable "terraform_state_bucket_name" {
  description = "Existing Terraform state bucket name. Defaults to the EventPulse convention."
  type        = string
  default     = null
}

variable "fluent_bit_namespace" {
  description = "Kubernetes namespace for AWS for Fluent Bit."
  type        = string
  default     = "amazon-cloudwatch"
}

variable "fluent_bit_service_account" {
  description = "Kubernetes service account used by AWS for Fluent Bit."
  type        = string
  default     = "aws-for-fluent-bit"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for EventPulse application logs."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "log_retention_days must be one of 1, 3, 5, 7, 14 or 30 for this dev environment."
  }
}
