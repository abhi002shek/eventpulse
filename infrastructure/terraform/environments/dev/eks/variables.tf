variable "region" {
  description = "AWS region for the dev EKS platform."
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

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "eventpulse-dev"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9-]{2,99}$", var.cluster_name))
    error_message = "cluster_name must start with a letter and contain only letters, numbers, and hyphens."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.36"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must use the EKS minor version format, for example 1.36."
  }
}

variable "cluster_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. Use the current operator public IP as /32."
  type        = list(string)

  validation {
    condition = (
      length(var.cluster_public_access_cidrs) > 0
      && alltrue([for cidr in var.cluster_public_access_cidrs : can(cidrhost(cidr, 0)) && can(regex("/32$", cidr))])
      && !contains(var.cluster_public_access_cidrs, "0.0.0.0/0")
    )
    error_message = "cluster_public_access_cidrs must contain valid IPv4 /32 CIDRs and must not include 0.0.0.0/0."
  }
}

variable "enabled_cluster_log_types" {
  description = "EKS control-plane log types to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention days for EKS control-plane logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([7, 14, 30, 60, 90, 180, 365], var.cluster_log_retention_days)
    error_message = "cluster_log_retention_days must be one of 7, 14, 30, 60, 90, 180, or 365."
  }
}

variable "node_instance_types" {
  description = "Managed node group instance types."
  type        = list(string)
  default     = ["t3.medium"]

  validation {
    condition     = length(var.node_instance_types) > 0 && alltrue([for instance_type in var.node_instance_types : can(regex("^[a-z][0-9a-z]+\\.[a-z0-9]+$", instance_type))])
    error_message = "node_instance_types must contain at least one valid EC2 instance type such as t3.medium."
  }
}

variable "node_desired_size" {
  description = "Desired managed node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum managed node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum managed node count."
  type        = number
  default     = 3
}

variable "node_disk_size_gib" {
  description = "Managed node root volume size in GiB."
  type        = number
  default     = 30

  validation {
    condition     = var.node_disk_size_gib >= 20 && var.node_disk_size_gib <= 100
    error_message = "node_disk_size_gib must be between 20 and 100."
  }
}

variable "enable_detailed_monitoring" {
  description = "Whether to enable detailed EC2 monitoring for managed nodes."
  type        = bool
  default     = false
}

variable "access_entry_principal_arn" {
  description = "IAM principal ARN to grant temporary dev cluster-admin access through EKS access entries."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/.+$", var.access_entry_principal_arn))
    error_message = "access_entry_principal_arn must be an IAM user or role ARN."
  }
}

variable "terraform_state_bucket_name" {
  description = "Optional Terraform state bucket name created by the bootstrap stack. When omitted, the dev naming convention is derived from the current AWS account and region."
  type        = string
  default     = null
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
