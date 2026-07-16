output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "kubernetes_version" {
  description = "EKS Kubernetes version."
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "EKS cluster IAM role ARN."
  value       = aws_iam_role.cluster.arn
}

output "node_group_name" {
  description = "Managed node group name."
  value       = aws_eks_node_group.general.node_group_name
}

output "node_iam_role_arn" {
  description = "Managed node IAM role ARN."
  value       = aws_iam_role.node.arn
}

output "node_group_status" {
  description = "Managed node group status."
  value       = aws_eks_node_group.general.status
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "access_entry_principal_arn" {
  description = "IAM principal ARN granted cluster-admin access through EKS access entries."
  value       = aws_eks_access_entry.operator.principal_arn
}

output "update_kubeconfig_command" {
  description = "Command for configuring kubectl after the cluster is applied."
  value       = "AWS_PROFILE=eventpulse-user aws eks update-kubeconfig --region ap-south-1 --name ${aws_eks_cluster.main.name}"
}

output "selected_private_subnet_ids" {
  description = "Private application subnet IDs used by the managed node group."
  value       = var.private_app_subnet_ids
}
