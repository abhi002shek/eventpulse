output "iam_role_arn" {
  description = "IAM role ARN associated with the controller service account."
  value       = aws_iam_role.controller.arn
}

output "iam_policy_arn" {
  description = "IAM policy ARN for AWS Load Balancer Controller."
  value       = aws_iam_policy.controller.arn
}

output "pod_identity_association_id" {
  description = "EKS Pod Identity association ID for AWS Load Balancer Controller."
  value       = aws_eks_pod_identity_association.controller.association_id
}
