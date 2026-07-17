output "eventpulse_log_group_name" {
  description = "CloudWatch Logs group used for EventPulse application logs."
  value       = aws_cloudwatch_log_group.eventpulse_application.name
}

output "eventpulse_log_group_arn" {
  description = "CloudWatch Logs group ARN used for EventPulse application logs."
  value       = aws_cloudwatch_log_group.eventpulse_application.arn
}

output "fluent_bit_role_arn" {
  description = "IAM role ARN associated with the AWS for Fluent Bit service account."
  value       = aws_iam_role.fluent_bit.arn
}

output "fluent_bit_pod_identity_association_id" {
  description = "EKS Pod Identity association ID for AWS for Fluent Bit."
  value       = aws_eks_pod_identity_association.fluent_bit.association_id
}
