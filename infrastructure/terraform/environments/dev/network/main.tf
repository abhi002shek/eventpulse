locals {
  common_tags = {
    Project            = var.project_name
    Environment        = var.environment
    ManagedBy          = "Terraform"
    Owner              = var.owner
    Purpose            = var.purpose
    DataClassification = "Internal"
  }
}

module "network" {
  source = "../../../modules/network"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  az_count                 = 2
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  enable_nat_gateway       = var.enable_nat_gateway
  enable_flow_logs         = var.enable_flow_logs
  tags                     = local.common_tags
}
