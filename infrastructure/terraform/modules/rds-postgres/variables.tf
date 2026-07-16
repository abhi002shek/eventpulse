variable "project_name" {
  description = "Project name used for naming and tags."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for RDS resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database will run."
  type        = string
}

variable "database_subnet_ids" {
  description = "Isolated database subnet IDs for the DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "database_subnet_ids must include at least two isolated subnets."
  }
}

variable "eks_workload_security_group_id" {
  description = "Security group used by EKS workloads that may connect to PostgreSQL."
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name for Pod Identity association."
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the EventPulse service account."
  type        = string
  default     = "eventpulse"
}

variable "kubernetes_service_account" {
  description = "Kubernetes service account allowed to read the database secret."
  type        = string
  default     = "eventpulse"
}

variable "db_identifier" {
  description = "RDS DB instance identifier."
  type        = string
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "eventpulse"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "master_username" {
  description = "RDS master username. The password is managed by RDS in Secrets Manager."
  type        = string
  default     = "eventpulse_admin"

  validation {
    condition = (
      !contains(["postgres", "admin", "root", "administrator"], lower(var.master_username))
      && can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.master_username))
    )
    error_message = "master_username must be a valid PostgreSQL username and must not be postgres, admin, root or administrator."
  }
}

variable "engine_version" {
  description = "Pinned PostgreSQL engine version."
  type        = string
}

variable "parameter_group_family" {
  description = "PostgreSQL parameter group family."
  type        = string
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

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
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

variable "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
