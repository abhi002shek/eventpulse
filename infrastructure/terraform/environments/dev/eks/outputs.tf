output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.eks.cluster_endpoint
}

output "kubernetes_version" {
  description = "EKS Kubernetes version."
  value       = module.eks.kubernetes_version
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "EKS cluster IAM role ARN."
  value       = module.eks.cluster_iam_role_arn
}

output "node_group_name" {
  description = "Managed node group name."
  value       = module.eks.node_group_name
}

output "node_iam_role_arn" {
  description = "Managed node IAM role ARN."
  value       = module.eks.node_iam_role_arn
}

output "node_group_status" {
  description = "Managed node group status."
  value       = module.eks.node_group_status
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL."
  value       = module.eks.oidc_issuer_url
}

output "access_entry_principal_arn" {
  description = "IAM principal ARN granted cluster-admin access through EKS access entries."
  value       = module.eks.access_entry_principal_arn
}

output "update_kubeconfig_command" {
  description = "Command for configuring kubectl after the cluster is applied."
  value       = module.eks.update_kubeconfig_command
}

output "selected_private_subnet_ids" {
  description = "Private application subnet IDs used by the managed node group."
  value       = module.eks.selected_private_subnet_ids
}
