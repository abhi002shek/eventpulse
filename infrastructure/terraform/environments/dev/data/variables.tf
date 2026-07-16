variable "region" {
  description = "AWS region for the dev data layer."
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
}

variable "terraform_state_bucket_name" {
  description = "Optional Terraform state bucket name created by the bootstrap stack. When omitted, the dev naming convention is derived from the current AWS account and region."
  type        = string
  default     = null
}

variable "db_identifier" {
  description = "RDS DB instance identifier."
  type        = string
  default     = "eventpulse-dev-postgres"
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "eventpulse"
}

variable "master_username" {
  description = "RDS master username. RDS manages the password in Secrets Manager."
  type        = string
  default     = "eventpulse_admin"
}

variable "engine_version" {
  description = "Pinned PostgreSQL engine version."
  type        = string
  default     = "17.5"
}

variable "parameter_group_family" {
  description = "PostgreSQL parameter group family."
  type        = string
  default     = "postgres17"
}

variable "instance_class" {
  description = "RDS DB instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage_gib" {
  description = "Initial allocated storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage_gib" {
  description = "Maximum storage autoscaling size in GiB."
  type        = number
  default     = 100
}

variable "backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window in UTC."
  type        = string
  default     = "20:30-21:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window in UTC."
  type        = string
  default     = "sun:21:30-sun:22:30"
}

variable "auto_minor_version_upgrade" {
  description = "Whether RDS may automatically apply minor version upgrades."
  type        = bool
  default     = true
}

variable "enabled_cloudwatch_logs_exports" {
  description = "PostgreSQL logs to export to CloudWatch."
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot when destroying."
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
