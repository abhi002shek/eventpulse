locals {
  cluster_role_name    = "${var.cluster_name}-cluster"
  node_role_name       = "${var.cluster_name}-nodes"
  launch_template_name = "${var.cluster_name}-nodes"

  node_labels = {
    environment    = var.environment
    workload-class = "general"
  }

  node_bootstrap_addons = {
    for addon_name, addon_version in var.addons : addon_name => addon_version
    if addon_name != "coredns"
  }
}

data "aws_caller_identity" "current" {}

resource "terraform_data" "node_size_guard" {
  input = {
    min     = var.node_min_size
    desired = var.node_desired_size
    max     = var.node_max_size
  }

  lifecycle {
    precondition {
      condition     = var.node_min_size <= var.node_desired_size && var.node_desired_size <= var.node_max_size
      error_message = "Node group sizing must satisfy minimum <= desired <= maximum."
    }
  }
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = local.cluster_role_name
  description        = "IAM role used by the ${var.cluster_name} EKS control plane."
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "cluster_secrets_key" {
  statement {
    sid = "AllowAccountAdministration"

    actions = [
      "kms:*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    resources = ["*"]
  }

  statement {
    sid = "AllowEksClusterSecretsEncryption"

    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cluster.arn]
    }

    resources = ["*"]
  }
}

resource "aws_kms_key" "cluster_secrets" {
  description             = "Customer managed KMS key for ${var.cluster_name} Kubernetes secret encryption."
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cluster_secrets_key.json

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-secrets"
  })
}

resource "aws_kms_alias" "cluster_secrets" {
  name          = "alias/${var.cluster_name}/secrets"
  target_key_id = aws_kms_key.cluster_secrets.key_id
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(var.tags, {
    Name = "/aws/eks/${var.cluster_name}/cluster"
  })
}

resource "aws_eks_cluster" "main" {
  name                          = var.cluster_name
  role_arn                      = aws_iam_role.cluster.arn
  version                       = var.kubernetes_version
  enabled_cluster_log_types     = var.enabled_cluster_log_types
  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster_secrets.arn
    }

    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids              = var.private_app_subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    #trivy:ignore:AVD-AWS-0040 Public access is intentionally limited to explicit operator /32 CIDRs during bootstrap.
    #tfsec:ignore:aws-eks-no-public-cluster-access Public access is intentionally limited to explicit operator /32 CIDRs during bootstrap.
    endpoint_public_access = var.cluster_endpoint_public_access
    public_access_cidrs    = var.cluster_public_access_cidrs
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster_policy,
    aws_kms_key.cluster_secrets,
  ]
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = local.node_role_name
  description        = "IAM role used by the ${var.node_group_name} EKS managed node group."
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_read_only" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_vpc_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_launch_template" "node" {
  name_prefix = "${local.launch_template_name}-"
  description = "Launch template for ${var.node_group_name} managed EKS nodes."

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.node_disk_size_gib
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.cluster_name}-managed-node"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.tags, {
      Name = "${var.cluster_name}-managed-node-root"
    })
  }

  tags = merge(var.tags, {
    Name = local.launch_template_name
  })
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_app_subnet_ids
  ami_type        = "AL2_x86_64"
  capacity_type   = "ON_DEMAND"
  instance_types  = var.node_instance_types
  labels          = local.node_labels

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.tags, {
    Name = var.node_group_name
  })

  depends_on = [
    terraform_data.node_size_guard,
    aws_eks_addon.node_bootstrap,
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr_read_only,
    aws_iam_role_policy_attachment.node_vpc_cni,
  ]
}

resource "aws_eks_addon" "node_bootstrap" {
  for_each = local.node_bootstrap_addons

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = each.key
  addon_version               = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = var.addons["coredns"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-coredns"
  })

  depends_on = [aws_eks_node_group.general]
}

resource "aws_eks_access_entry" "operator" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.access_entry_principal_arn
  type          = "STANDARD"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-operator-access"
  })
}

resource "aws_eks_access_policy_association" "operator_cluster_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.operator.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
