data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  terraform_state_bucket_name = coalesce(
    var.terraform_state_bucket_name,
    lower("${var.project_name}-${var.environment}-terraform-state-${data.aws_caller_identity.current.account_id}-${var.region}"),
  )

  common_tags = {
    Project            = var.project_name
    Environment        = var.environment
    ManagedBy          = "Terraform"
    Owner              = var.owner
    Purpose            = var.purpose
    DataClassification = "Internal"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket       = local.terraform_state_bucket_name
    key          = "eventpulse/dev/network/terraform.tfstate"
    region       = var.region
    encrypt      = true
    use_lockfile = true
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket       = local.terraform_state_bucket_name
    key          = "eventpulse/dev/eks/terraform.tfstate"
    region       = var.region
    encrypt      = true
    use_lockfile = true
  }
}

module "postgres" {
  source = "../../../modules/rds-postgres"

  project_name                   = var.project_name
  environment                    = var.environment
  name_prefix                    = local.name_prefix
  vpc_id                         = data.terraform_remote_state.network.outputs.vpc_id
  database_subnet_ids            = data.terraform_remote_state.network.outputs.private_db_subnet_ids
  eks_workload_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  eks_cluster_name               = data.terraform_remote_state.eks.outputs.cluster_name
  kubernetes_namespace           = "eventpulse"
  kubernetes_service_account     = "eventpulse"

  db_identifier                   = var.db_identifier
  db_name                         = var.db_name
  master_username                 = var.master_username
  engine_version                  = var.engine_version
  parameter_group_family          = var.parameter_group_family
  instance_class                  = var.instance_class
  allocated_storage_gib           = var.allocated_storage_gib
  max_allocated_storage_gib       = var.max_allocated_storage_gib
  backup_retention_days           = var.backup_retention_days
  backup_window                   = var.backup_window
  maintenance_window              = var.maintenance_window
  auto_minor_version_upgrade      = var.auto_minor_version_upgrade
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  tags                            = local.common_tags
}
