locals {
  db_port                   = 5432
  final_snapshot_identifier = "${var.db_identifier}-final-snapshot"
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.name_prefix}-postgres"
  description = "Isolated database subnets for ${var.name_prefix} PostgreSQL."
  subnet_ids  = var.database_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
  })
}

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-postgres"
  description = "Allow EventPulse EKS workloads to reach PostgreSQL."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
  })
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = var.eks_workload_security_group_id
  description                  = "PostgreSQL from EventPulse EKS workloads"
  from_port                    = local.db_port
  to_port                      = local.db_port
  ip_protocol                  = "tcp"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres-from-eks"
  })
}

resource "aws_db_parameter_group" "main" {
  name        = "${var.name_prefix}-postgres"
  family      = var.parameter_group_family
  description = "PostgreSQL parameters for ${var.name_prefix}."

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
  })
}

resource "aws_db_instance" "main" {
  identifier = var.db_identifier

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.master_username
  port     = local.db_port

  manage_master_user_password = true

  allocated_storage     = var.allocated_storage_gib
  max_allocated_storage = var.max_allocated_storage_gib
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = false

  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade      = var.auto_minor_version_upgrade
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled    = var.performance_insights_enabled
  monitoring_interval             = 0

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_identifier
  delete_automated_backups  = false

  tags = merge(var.tags, {
    Name = var.db_identifier
  })
}

resource "aws_secretsmanager_secret_policy" "database" {
  secret_arn = aws_db_instance.main.master_user_secret[0].secret_arn

  policy = data.aws_iam_policy_document.database_secret_resource_policy.json
}

data "aws_iam_policy_document" "database_secret_resource_policy" {
  statement {
    sid = "AllowAccountMetadataAccess"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.pod_identity.arn]
    }

    resources = [aws_db_instance.main.master_user_secret[0].secret_arn]
  }
}

data "aws_iam_policy_document" "pod_identity_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pod_identity" {
  name               = "${var.name_prefix}-eventpulse-db-secret"
  description        = "Allows the EventPulse Kubernetes service account to read its RDS secret."
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "pod_identity_permissions" {
  statement {
    sid = "ReadEventPulseDatabaseSecret"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = [aws_db_instance.main.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "pod_identity" {
  name   = "${var.name_prefix}-database-secret-read"
  role   = aws_iam_role.pod_identity.id
  policy = data.aws_iam_policy_document.pod_identity_permissions.json
}

resource "aws_eks_pod_identity_association" "eventpulse" {
  cluster_name    = var.eks_cluster_name
  namespace       = var.kubernetes_namespace
  service_account = var.kubernetes_service_account
  role_arn        = aws_iam_role.pod_identity.arn

  tags = var.tags
}
