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

module "aws_load_balancer_controller" {
  source = "../../../modules/aws-load-balancer-controller"

  name_prefix                = local.name_prefix
  eks_cluster_name           = data.terraform_remote_state.eks.outputs.cluster_name
  kubernetes_namespace       = "kube-system"
  kubernetes_service_account = "aws-load-balancer-controller"
  tags                       = local.common_tags
}
