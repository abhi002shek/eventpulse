# AWS Terraform Bootstrap Runbook

This runbook creates the AWS Terraform state bucket first, then uses that bucket
for the dev network stack.

## Prerequisites

- Terraform `>= 1.10.0`
- AWS CLI configured through the normal AWS credential chain
- AWS region `ap-south-1`
- permission to create S3, KMS, VPC, subnet, route table, NAT gateway, Elastic
  IP and IAM resources when optional VPC Flow Logs are enabled

Do not put AWS credentials in repository files.

## Verify AWS Identity

```bash
aws sts get-caller-identity
```

Review the account and ARN before planning or applying. Stop if the account is
not the intended dev account.

## Bootstrap State Bucket

```bash
cd infrastructure/terraform/bootstrap
terraform init
terraform plan -out=tfplan
```

Review the plan. It should create only the Terraform state S3 bucket, its
customer managed KMS key and related bucket controls.

Apply only after explicit approval:

```bash
terraform apply tfplan
terraform output terraform_state_bucket_name
```

The bootstrap state is local at first. Protect the local state file until the
bootstrap resources are safely tracked.

## Configure Network Backend

Copy the example backend file outside Git tracking:

```bash
cd ../environments/dev/network
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` and replace `ACCOUNT_ID` with the AWS account ID from the
bootstrap output.

The backend key is:

```text
eventpulse/dev/network/terraform.tfstate
```

The backend uses:

```hcl
use_lockfile = true
```

No DynamoDB lock table is used.

## Initialize And Plan Network

```bash
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=tfplan
```

Review the plan carefully before applying. Expected network resources include:

- VPC `10.30.0.0/16`
- two public subnets without automatic public IPv4 assignment
- two private application subnets
- two isolated private database subnets
- Internet Gateway
- one NAT gateway and one Elastic IP when NAT is enabled
- route tables, routes and route-table associations

Apply only after explicit approval:

```bash
terraform apply tfplan
terraform output
```

## Cost Checks

The VPC itself has no direct hourly charge. The main ongoing costs in this
milestone are:

- NAT gateway hourly charge
- NAT data processing
- public IPv4 address used by the NAT gateway
- minimal S3 state storage
- KMS key requests for Terraform state encryption

`enable_nat_gateway = false` can avoid NAT costs, but private application
subnets then cannot reach the public Internet for package downloads or image
pulls through the NAT path.

## Safe Destroy Order

Destroy the network before the bootstrap stack:

```bash
cd infrastructure/terraform/environments/dev/network
terraform plan -destroy -out=tfplan
terraform apply tfplan
```

Only after network state is safely removed should the bootstrap resources be
considered. The state bucket has `prevent_destroy = true`; removing it requires
an intentional code change and careful state backup.

## State Recovery Notes

S3 bucket versioning is enabled for state history. If state is damaged, inspect
previous object versions before overwriting anything.

Do not run broad S3 deletion or lifecycle cleanup commands against the state
bucket.
