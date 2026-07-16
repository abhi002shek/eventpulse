locals {
  common_tags = {
    Project            = var.project_name
    Environment        = var.environment
    ManagedBy          = "Terraform"
    Owner              = var.owner
    Purpose            = var.purpose
    DataClassification = "Internal"
  }

  eks_addons = {
    vpc-cni                = "v1.21.2-eksbuild.2"
    coredns                = "v1.14.2-eksbuild.4"
    kube-proxy             = "v1.36.0-eksbuild.7"
    eks-pod-identity-agent = "v1.3.10-eksbuild.3"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket       = var.terraform_state_bucket_name
    key          = "eventpulse/dev/network/terraform.tfstate"
    region       = var.region
    encrypt      = true
    use_lockfile = true
  }
}

module "eks" {
  source = "../../../modules/eks"

  project_name                = var.project_name
  environment                 = var.environment
  cluster_name                = var.cluster_name
  kubernetes_version          = var.kubernetes_version
  private_app_subnet_ids      = data.terraform_remote_state.network.outputs.private_app_subnet_ids
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  enabled_cluster_log_types   = var.enabled_cluster_log_types
  cluster_log_retention_days  = var.cluster_log_retention_days
  node_instance_types         = var.node_instance_types
  node_desired_size           = var.node_desired_size
  node_min_size               = var.node_min_size
  node_max_size               = var.node_max_size
  node_disk_size_gib          = var.node_disk_size_gib
  enable_detailed_monitoring  = var.enable_detailed_monitoring
  addons                      = local.eks_addons
  access_entry_principal_arn  = var.access_entry_principal_arn
  tags                        = local.common_tags
}
