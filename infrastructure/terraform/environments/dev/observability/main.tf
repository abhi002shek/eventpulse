data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  terraform_state_bucket_name = coalesce(
    var.terraform_state_bucket_name,
    lower("${var.project_name}-${var.environment}-terraform-state-${data.aws_caller_identity.current.account_id}-${var.region}"),
  )

  eventpulse_log_group_name = "/aws/eks/${local.name_prefix}/eventpulse/application"

  common_tags = {
    Project            = var.project_name
    Environment        = var.environment
    ManagedBy          = "Terraform"
    Owner              = var.owner
    Purpose            = var.purpose
    DataClassification = "Internal"
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

resource "aws_cloudwatch_log_group" "eventpulse_application" {
  name              = local.eventpulse_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = local.eventpulse_log_group_name
  })
}

data "aws_iam_policy_document" "fluent_bit_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
  }
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${local.name_prefix}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume_role.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-fluent-bit"
  })
}

data "aws_iam_policy_document" "fluent_bit_logs" {
  statement {
    sid    = "WriteEventPulseApplicationLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]

    resources = [
      aws_cloudwatch_log_group.eventpulse_application.arn,
      "${aws_cloudwatch_log_group.eventpulse_application.arn}:log-stream:*",
    ]
  }
}

resource "aws_iam_policy" "fluent_bit_logs" {
  name        = "${local.name_prefix}-fluent-bit-logs"
  description = "Allow AWS for Fluent Bit to write EventPulse application logs."
  policy      = data.aws_iam_policy_document.fluent_bit_logs.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-fluent-bit-logs"
  })
}

resource "aws_iam_role_policy_attachment" "fluent_bit_logs" {
  role       = aws_iam_role.fluent_bit.name
  policy_arn = aws_iam_policy.fluent_bit_logs.arn
}

resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = var.fluent_bit_namespace
  service_account = var.fluent_bit_service_account
  role_arn        = aws_iam_role.fluent_bit.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-fluent-bit"
  })
}
