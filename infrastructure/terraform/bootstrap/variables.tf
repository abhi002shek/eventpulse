variable "region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "region must be a valid AWS region name such as ap-south-1."
  }
}

variable "environment" {
  description = "Short environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev"], var.environment)
    error_message = "environment must be dev for this milestone."
  }
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "eventpulse"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens."
  }
}

variable "owner" {
  description = "Non-sensitive owner label for tags."
  type        = string
  default     = "platform"
}

variable "purpose" {
  description = "Cost or purpose label for tags."
  type        = string
  default     = "portfolio-dev"
}
