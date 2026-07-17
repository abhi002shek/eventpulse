variable "region" {
  description = "AWS region for the dev platform resources."
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
