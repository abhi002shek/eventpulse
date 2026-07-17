output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller."
  value       = module.aws_load_balancer_controller.iam_role_arn
}

output "aws_load_balancer_controller_policy_arn" {
  description = "IAM policy ARN for AWS Load Balancer Controller."
  value       = module.aws_load_balancer_controller.iam_policy_arn
}

output "aws_load_balancer_controller_pod_identity_association_id" {
  description = "Pod Identity association ID for AWS Load Balancer Controller."
  value       = module.aws_load_balancer_controller.pod_identity_association_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs where internet-facing ALBs may be placed."
  value       = data.terraform_remote_state.network.outputs.public_subnet_ids
}
