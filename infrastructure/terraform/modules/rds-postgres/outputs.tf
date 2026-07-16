output "db_instance_identifier" {
  description = "RDS DB instance identifier."
  value       = aws_db_instance.main.identifier
}

output "db_endpoint" {
  description = "RDS DB instance endpoint."
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS PostgreSQL port."
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.main.db_name
}

output "db_engine_version" {
  description = "Pinned PostgreSQL engine version."
  value       = aws_db_instance.main.engine_version_actual
}

output "db_subnet_group_name" {
  description = "RDS DB subnet group name."
  value       = aws_db_subnet_group.main.name
}

output "rds_security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.database.id
}

output "master_secret_arn" {
  description = "RDS-managed master user secret ARN."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "application_secret_arn" {
  description = "Secret ARN the EventPulse workload is allowed to read."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "pod_identity_role_arn" {
  description = "IAM role ARN associated with the EventPulse Kubernetes service account."
  value       = aws_iam_role.pod_identity.arn
}

output "pod_identity_association_id" {
  description = "EKS Pod Identity association ID."
  value       = aws_eks_pod_identity_association.eventpulse.association_id
}

output "selected_database_subnet_ids" {
  description = "Database subnet IDs used by the DB subnet group."
  value       = var.database_subnet_ids
}
