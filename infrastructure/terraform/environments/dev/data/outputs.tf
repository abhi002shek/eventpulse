output "db_instance_identifier" {
  description = "RDS DB instance identifier."
  value       = module.postgres.db_instance_identifier
}

output "db_endpoint" {
  description = "RDS DB instance endpoint."
  value       = module.postgres.db_endpoint
}

output "db_port" {
  description = "RDS PostgreSQL port."
  value       = module.postgres.db_port
}

output "db_name" {
  description = "Initial database name."
  value       = module.postgres.db_name
}

output "db_engine_version" {
  description = "Pinned PostgreSQL engine version."
  value       = module.postgres.db_engine_version
}

output "db_subnet_group_name" {
  description = "RDS DB subnet group name."
  value       = module.postgres.db_subnet_group_name
}

output "rds_security_group_id" {
  description = "RDS security group ID."
  value       = module.postgres.rds_security_group_id
}

output "master_secret_arn" {
  description = "RDS-managed master user secret ARN."
  value       = module.postgres.master_secret_arn
}

output "application_secret_arn" {
  description = "Secret ARN the EventPulse workload is allowed to read."
  value       = module.postgres.application_secret_arn
}

output "pod_identity_role_arn" {
  description = "IAM role ARN associated with the EventPulse Kubernetes service account."
  value       = module.postgres.pod_identity_role_arn
}

output "pod_identity_association_id" {
  description = "EKS Pod Identity association ID."
  value       = module.postgres.pod_identity_association_id
}

output "selected_database_subnet_ids" {
  description = "Database subnet IDs used by the DB subnet group."
  value       = module.postgres.selected_database_subnet_ids
}
