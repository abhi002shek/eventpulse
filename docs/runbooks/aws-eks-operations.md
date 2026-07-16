# AWS EKS Operations Runbook

This runbook plans and operates the dev EKS platform for EventPulse. It assumes
the Milestone 6A network foundation has already been applied.

## Prerequisites

- Terraform `>= 1.10.0`
- AWS CLI
- AWS profile `eventpulse-user`
- Region `ap-south-1`
- Existing Terraform state bucket
- Existing network state at `eventpulse/dev/network/terraform.tfstate`

Do not put AWS credentials, public IP values or local `backend.hcl` files in
Git.

## Verify Identity

```bash
AWS_PROFILE=eventpulse-user aws sts get-caller-identity
```

The originally expected IAM user principal is:

```text
arn:aws:iam::616919332376:user/eventpulse-user
```

Stop if the identity is root or an unexpected account. If AWS SSO is being used,
review whether the EKS access-entry principal should be the SSO role rather than
the IAM user before planning.

For example, the access-entry principal is supplied at plan/apply time:

```bash
-var='access_entry_principal_arn=arn:aws:iam::616919332376:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_53a6897436c024c1'
```

## Configure Backend

```bash
cd infrastructure/terraform/environments/dev/eks
cp backend.hcl.example backend.hcl
```

Replace `ACCOUNT_ID` with the AWS account ID. The backend key is:

```text
eventpulse/dev/eks/terraform.tfstate
```

The backend uses S3 native lock files:

```hcl
use_lockfile = true
```

No DynamoDB lock table is used.

## Get Operator Public IP

Use the current workstation public IP as a `/32` for the EKS API public endpoint:

```bash
curl -fsS https://checkip.amazonaws.com
```

Do not commit this value. Pass it to Terraform only at plan/apply time:

```bash
-var='cluster_public_access_cidrs=["203.0.113.10/32"]'
```

## Initialize And Validate

```bash
terraform init -backend-config=backend.hcl
terraform validate
```

## Plan

```bash
terraform plan \
  -out=tfplan \
  -var='terraform_state_bucket_name=eventpulse-dev-terraform-state-ACCOUNT_ID-ap-south-1' \
  -var='cluster_public_access_cidrs=["CURRENT_PUBLIC_IP/32"]' \
  -var='access_entry_principal_arn=OPERATOR_IAM_PRINCIPAL_ARN'
```

Review the plan. It should create EKS platform resources only:

- EKS cluster
- CloudWatch log group
- cluster IAM role and policy attachment
- node IAM role and policy attachments
- launch template
- managed node group
- EKS add-ons
- EKS access entry and policy association

Stop if the plan includes VPC replacement, subnet replacement, NAT replacement,
RDS, load balancers, Route 53, application workloads, SSH key pairs,
AdministratorAccess on node roles, public worker-node IPs or API access from
`0.0.0.0/0`.

## Apply

Apply only after explicit approval:

```bash
terraform apply tfplan
```

## Configure kubectl

After apply:

```bash
AWS_PROFILE=eventpulse-user aws eks update-kubeconfig \
  --region ap-south-1 \
  --name eventpulse-dev
```

Validate:

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```

## Check Nodes And Add-ons

```bash
AWS_PROFILE=eventpulse-user aws eks describe-nodegroup \
  --region ap-south-1 \
  --cluster-name eventpulse-dev \
  --nodegroup-name eventpulse-dev-general

AWS_PROFILE=eventpulse-user aws eks list-addons \
  --region ap-south-1 \
  --cluster-name eventpulse-dev
```

## Access-entry Recovery

If the operator cannot access Kubernetes, inspect EKS access entries from AWS:

```bash
AWS_PROFILE=eventpulse-user aws eks list-access-entries \
  --region ap-south-1 \
  --cluster-name eventpulse-dev
```

Add or repair access through Terraform rather than manually changing cluster
authentication.

## Update API CIDRs

When the operator public IP changes, update the CIDR variable and run a new
plan/apply:

```bash
terraform plan \
  -out=tfplan \
  -var='terraform_state_bucket_name=eventpulse-dev-terraform-state-ACCOUNT_ID-ap-south-1' \
  -var='cluster_public_access_cidrs=["NEW_PUBLIC_IP/32"]' \
  -var='access_entry_principal_arn=OPERATOR_IAM_PRINCIPAL_ARN'
```

## Scale The Node Group

Adjust `node_desired_size`, `node_min_size` and `node_max_size` through
Terraform variables. Keep `minimum <= desired <= maximum`.

Scaling worker nodes to zero is not part of the default milestone design and
does not stop EKS control-plane charges.

## Upgrade Workflow

1. Query supported EKS versions in `ap-south-1`.
2. Confirm the target version is in standard support.
3. Query compatible add-on versions.
4. Update Terraform variables and pinned add-on versions.
5. Plan and review.
6. Apply during a maintenance window.
7. Validate node and add-on health.

## Safe Destroy

Destroy application workloads first in later milestones. For this milestone,
destroy EKS before deleting the network:

```bash
cd infrastructure/terraform/environments/dev/eks
terraform plan -destroy -out=tfplan \
  -var='terraform_state_bucket_name=eventpulse-dev-terraform-state-ACCOUNT_ID-ap-south-1' \
  -var='cluster_public_access_cidrs=["CURRENT_PUBLIC_IP/32"]' \
  -var='access_entry_principal_arn=OPERATOR_IAM_PRINCIPAL_ARN'
terraform apply tfplan
```

Then destroy the network only when no cluster resources remain.

## Common Node-join Failures

- Private subnets cannot reach EKS or registries through NAT.
- Node IAM role is missing worker, ECR or CNI permissions.
- Launch template accidentally assigns public IPs or uses a custom AMI.
- Security groups or network ACLs block control-plane-to-node communication.
- Add-on versions are incompatible with the cluster version.

## NAT And DNS Troubleshooting

Check that private application subnets have a default route to the NAT gateway
and that VPC DNS support and hostnames are enabled. Nodes in private subnets
need outbound access for image pulls and AWS API calls unless VPC endpoints are
added in a later milestone.

## Cost Shutdown Limits

Stopping or scaling down nodes reduces EC2 and EBS costs, but the EKS control
plane continues billing until the cluster is destroyed. NAT gateway costs also
continue while the NAT gateway exists.
