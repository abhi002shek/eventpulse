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

resource "aws_iam_policy" "controller" {
  name        = "${var.name_prefix}-aws-load-balancer-controller"
  description = "Least-privilege IAM policy for AWS Load Balancer Controller."
  policy      = file("${path.module}/policies/aws-load-balancer-controller-v3.4.2-iam-policy.json")

  tags = var.tags
}

resource "aws_iam_role" "controller" {
  name               = "${var.name_prefix}-aws-load-balancer-controller"
  description        = "EKS Pod Identity role for AWS Load Balancer Controller."
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

resource "aws_eks_pod_identity_association" "controller" {
  cluster_name    = var.eks_cluster_name
  namespace       = var.kubernetes_namespace
  service_account = var.kubernetes_service_account
  role_arn        = aws_iam_role.controller.arn

  tags = var.tags
}
