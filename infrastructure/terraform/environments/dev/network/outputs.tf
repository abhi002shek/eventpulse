output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = module.network.vpc_cidr
}

output "availability_zones" {
  description = "Selected Availability Zones."
  value       = module.network.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs."
  value       = module.network.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs."
  value       = module.network.private_db_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID, or null when NAT is disabled."
  value       = module.network.nat_gateway_id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID."
  value       = module.network.internet_gateway_id
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = module.network.public_route_table_id
}

output "private_app_route_table_id" {
  description = "Private application route table ID."
  value       = module.network.private_app_route_table_id
}

output "private_db_route_table_id" {
  description = "Private database route table ID."
  value       = module.network.private_db_route_table_id
}

output "terraform_state_bucket_name" {
  description = "Terraform state bucket name created by the bootstrap stack."
  value       = var.terraform_state_bucket_name
}
