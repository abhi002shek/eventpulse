variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["dev"], var.environment)
    error_message = "environment must be dev for this milestone."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count == 2
    error_message = "az_count must be 2 for this milestone."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "public_subnet_cidrs must contain exactly two valid IPv4 CIDR blocks."
  }
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2 && alltrue([for cidr in var.private_app_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "private_app_subnet_cidrs must contain exactly two valid IPv4 CIDR blocks."
  }
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for isolated private database subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2 && alltrue([for cidr in var.private_db_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "private_db_subnet_cidrs must contain exactly two valid IPv4 CIDR blocks."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to create the single dev NAT gateway for private application subnet egress."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs to CloudWatch Logs."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention in days when VPC Flow Logs are enabled."
  type        = number
  default     = 30

  validation {
    condition     = contains([7, 14, 30, 60, 90, 180, 365], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be one of 7, 14, 30, 60, 90, 180, or 365."
  }
}

variable "tags" {
  description = "Standard tags to apply to resources."
  type        = map(string)
  default     = {}
}
