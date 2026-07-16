output "terraform_state_bucket_name" {
  description = "S3 bucket name for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_region" {
  description = "AWS region containing the Terraform state bucket."
  value       = var.region
}

output "network_state_key" {
  description = "Recommended S3 backend key for the dev network stack."
  value       = "eventpulse/dev/network/terraform.tfstate"
}
