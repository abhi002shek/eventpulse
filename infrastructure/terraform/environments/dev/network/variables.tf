variable "region" {
  description = "AWS region for the dev network."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = var.region == "ap-south-1"
    error_message = "region must be ap-south-1 for the dev environment."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "environment must be dev."
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

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.30.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks."
  type        = list(string)
  default     = ["10.30.0.0/24", "10.30.1.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private application subnet CIDR blocks."
  type        = list(string)
  default     = ["10.30.10.0/24", "10.30.11.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Private database subnet CIDR blocks."
  type        = list(string)
  default     = ["10.30.20.0/24", "10.30.21.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create the single dev NAT gateway."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs to CloudWatch Logs."
  type        = bool
  default     = false
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

variable "terraform_state_bucket_name" {
  description = "Terraform state bucket name created by the bootstrap stack."
  type        = string
  default     = null
}
