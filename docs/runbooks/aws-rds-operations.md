# AWS RDS Operations Runbook

This runbook covers the EventPulse dev RDS PostgreSQL data layer. It does not
deploy the EventPulse Helm chart.

## Prerequisites

- AWS CLI authenticated with `AWS_PROFILE=eventpulse-user`.
- Terraform `>= 1.10`.
- Existing EventPulse network and EKS states.
- EKS cluster `eventpulse-dev` active with managed nodes Ready.

Use:

```bash
export AWS_PROFILE=eventpulse-user
export AWS_REGION=ap-south-1
```

Verify identity:

```bash
aws sts get-caller-identity
```

The ARN must be an assumed role or IAM principal, not account root.

## Backend Initialization

```bash
cd infrastructure/terraform/environments/dev/data
terraform init \
  -backend-config='bucket=eventpulse-dev-terraform-state-ACCOUNT_ID-ap-south-1'
```

The state key is fixed in Terraform:

```text
eventpulse/dev/data/terraform.tfstate
```

The backend uses S3 encryption and native S3 lockfiles. It does not use a
DynamoDB lock table.

## Pre-Plan Checks

Verify network state:

```bash
cd infrastructure/terraform/environments/dev/network
terraform plan -detailed-exitcode \
  -var='terraform_state_bucket_name=eventpulse-dev-terraform-state-ACCOUNT_ID-ap-south-1'
```

An output-only state update is acceptable, but the plan must not replace VPC,
subnets, route tables, NAT or Internet Gateway resources.

Verify EKS state:

```bash
cd infrastructure/terraform/environments/dev/eks
terraform plan -detailed-exitcode \
  -var='cluster_public_access_cidrs=["CURRENT_PUBLIC_IP/32"]' \
  -var='access_entry_principal_arn=OPERATOR_IAM_PRINCIPAL_ARN'
```

The EKS plan must show no changes.

Verify nodes:

```bash
aws eks update-kubeconfig --region ap-south-1 --name eventpulse-dev
kubectl get nodes
```

Verify isolated database subnet routing:

```bash
aws ec2 describe-route-tables \
  --filters Name=association.subnet-id,Values=DB_SUBNET_1,DB_SUBNET_2
```

Database subnet route tables must not contain a default route to an Internet
Gateway or NAT Gateway.

## Plan Review

```bash
cd infrastructure/terraform/environments/dev/data
terraform plan -out=tfplan
```

Review the plan. It should create only:

- RDS PostgreSQL instance `eventpulse-dev-postgres`
- DB subnet group using isolated database subnets
- RDS security group
- PostgreSQL parameter group with `rds.force_ssl = 1`
- RDS-managed Secrets Manager secret metadata
- IAM role and policy for EKS Pod Identity
- EKS Pod Identity association

Stop if the plan contains:

- VPC, subnet, NAT or EKS replacement
- publicly accessible RDS
- ingress from `0.0.0.0/0`
- ingress from an operator public IP
- database placement in app or public subnets
- plaintext password outputs
- broad Secrets Manager permissions
- application deployment
- load balancer, Route 53 or ACM
- automatic rotation Lambda
- Multi-AZ unless explicitly approved

## Apply Sequence

Apply only after explicit approval:

```bash
terraform apply tfplan
```

Do not commit `tfplan`.

## Availability Checks

After apply:

```bash
aws rds describe-db-instances \
  --db-instance-identifier eventpulse-dev-postgres
```

Wait for `DBInstanceStatus` to become `available`.

Inspect secret metadata without revealing the value:

```bash
aws secretsmanager describe-secret \
  --secret-id SECRET_ARN
```

Do not run `get-secret-value` in shared terminal logs unless you have a specific
operational need and a safe output-handling plan.

## Pod Identity Verification

Check the association:

```bash
aws eks list-pod-identity-associations \
  --cluster-name eventpulse-dev
```

The EventPulse association should target:

```text
namespace: eventpulse
serviceAccount: eventpulse
```

The IAM role should allow only `secretsmanager:DescribeSecret` and
`secretsmanager:GetSecretValue` on the EventPulse database secret ARN.

## TLS Connectivity Testing

RDS enforces TLS with `rds.force_ssl = 1`. Initial client settings should use:

```text
sslmode=require
```

For stronger validation, install the current AWS RDS CA bundle into the
application runtime and move to:

```text
sslmode=verify-full
```

Do not disable TLS to make a connection test pass.

## Migration Connectivity

In the deployment milestone, run migrations from the EventPulse image after the
Secrets Store CSI integration is installed and the Kubernetes Secret is synced.
Do not run migrations from a laptop against the private RDS endpoint unless you
have a controlled private network path.

## Backup And Restore Checks

Automated backups are retained for seven days. Validate restore by creating a
temporary restored DB instance during a later recovery exercise, then remove it
after verification.

Manual snapshots may be used before risky changes. Tag snapshots clearly and
delete them when no longer required.

## Password Rotation Planning

Automatic rotation is postponed. A complete rotation design needs:

- a Lambda rotation function
- VPC access to the database
- security group rules for the rotation function
- testing for application secret reload behavior

Do not enable partial rotation.

## Controlled Destroy

Default settings intentionally block accidental deletion:

```text
deletion_protection = true
skip_final_snapshot = false
```

For a lab destroy, make an explicit plan that first disables deletion
protection. Choose whether to retain the final snapshot.

After destroy, review retained resources:

- final snapshots
- retained automated backups
- Secrets Manager secrets pending deletion
- CloudWatch logs

Secrets use a recovery window. They may continue to exist, and incur cost, until
the recovery window expires.

## Troubleshooting

- DNS failure: confirm the Pod runs in the VPC and can resolve the RDS endpoint.
- Timeout: check RDS security group source and NetworkPolicy egress.
- TLS failure: verify `PGSSLMODE` and RDS CA handling.
- Authentication failure: inspect secret metadata and Pod Identity association;
  do not print the password.
- Public access concern: confirm `PubliclyAccessible` is false and the subnet
  group contains only isolated database subnet IDs.
