output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "Selected Availability Zones."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = [for key in sort(keys(aws_subnet.public)) : aws_subnet.public[key].id]
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs."
  value       = [for key in sort(keys(aws_subnet.private_app)) : aws_subnet.private_app[key].id]
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs."
  value       = [for key in sort(keys(aws_subnet.private_db)) : aws_subnet.private_db[key].id]
}

output "internet_gateway_id" {
  description = "Internet Gateway ID."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID, or null when NAT is disabled."
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = aws_route_table.public.id
}

output "private_app_route_table_id" {
  description = "Private application route table ID."
  value       = aws_route_table.private_app.id
}

output "private_db_route_table_id" {
  description = "Private database route table ID."
  value       = aws_route_table.private_db.id
}
