# AWS Complete Shutdown Runbook

This runbook describes a safe ordered teardown for the EventPulse AWS dev workload.

Do not use `terraform destroy -auto-approve`. Always review plans before applying or destroying.

The Terraform bootstrap/state bucket must remain unless the operator explicitly chooses permanent project deletion.

## Preconditions

```bash
export AWS_PROFILE=eventpulse-user
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity
```

Stop if the principal is the AWS account root user.

## 1. Capture Final Evidence

Capture screenshots and command output listed in:

- `docs/evidence/screenshot-checklist.md`
- `docs/evidence/validation-summary.md`

## 2. Remove EventPulse Ingress

Remove the public Ingress and wait for ALB deletion:

```bash
ops/eks/remove-public-ingress.sh
```

Confirm no EventPulse ALB remains:

```bash
aws elbv2 describe-load-balancers --region ap-south-1 --output table
aws elbv2 describe-target-groups --region ap-south-1 --output table
```

## 3. Remove Observability Helm Resources

```bash
ops/eks/uninstall-observability.sh
```

This removes Helm releases and dashboard ConfigMaps. It does not destroy Terraform-managed CloudWatch/IAM resources.

## 4. Remove EventPulse Helm Release

```bash
ops/eks/uninstall-eventpulse.sh
```

Confirm workload resources are gone:

```bash
kubectl -n eventpulse get all,ingress,servicemonitor,prometheusrule
```

## 5. Remove Cluster Controllers When Appropriate

Remove Kyverno, Secrets Store CSI provider/driver and AWS Load Balancer Controller only after workloads and ALB resources are gone.

Use the existing runbooks/scripts where available:

```bash
ops/eks/install-kyverno.sh
ops/eks/install-secrets-provider.sh
ops/eks/install-aws-load-balancer-controller.sh
```

These install scripts document the components; remove with Helm only after confirming no dependent workloads remain.

## 6. Destroy Observability Terraform State

```bash
cd infrastructure/terraform/environments/dev/observability
terraform plan -destroy -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

This removes the CloudWatch log group, Fluent Bit role/policy and Pod Identity association. Decide whether logs should be exported before destroy.

## 7. Destroy Platform Terraform State

```bash
cd infrastructure/terraform/environments/dev/platform
terraform plan -destroy -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

This removes platform IAM resources such as AWS Load Balancer Controller Pod Identity resources.

## 8. Prepare Data Stack For Destroy

Before destroying RDS:

1. Decide whether to create a final snapshot.
2. Disable deletion protection through Terraform with a narrow reviewed change.
3. Apply only that change.
4. Confirm the final snapshot choice is intentional.

Then:

```bash
cd infrastructure/terraform/environments/dev/data
terraform plan -destroy -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

Remember Secrets Manager secrets can have recovery windows.

## 9. Destroy EKS Terraform State

```bash
cd infrastructure/terraform/environments/dev/eks
terraform plan -destroy -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

Watch for:

- EKS access endpoint state.
- Pod Identity associations.
- Managed add-ons.
- ENI cleanup.
- Node group termination.

## 10. Destroy Network Terraform State

Only after EKS, RDS and controllers are gone:

```bash
cd infrastructure/terraform/environments/dev/network
terraform plan -destroy -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

Watch for NAT Gateway, Elastic IP and ENI dependencies.

## 11. Retain Bootstrap State Bucket

Do not destroy the bootstrap S3 Terraform state bucket unless this is permanent project deletion.

## Pre-Destroy Inventory

```bash
aws eks list-clusters --region ap-south-1
aws rds describe-db-instances --region ap-south-1 --output table
aws elbv2 describe-load-balancers --region ap-south-1 --output table
aws ec2 describe-nat-gateways --region ap-south-1 --output table
aws ec2 describe-addresses --region ap-south-1 --output table
aws logs describe-log-groups --region ap-south-1 --output table
aws secretsmanager list-secrets --region ap-south-1 --output table
```

## Post-Destroy Cost-Leak Checklist

Check for:

- Load balancers
- Target groups
- NAT gateways
- Elastic IPs
- EC2 instances
- EBS volumes
- RDS instances
- RDS snapshots
- EKS clusters
- CloudWatch log groups
- Secrets Manager secrets
- KMS keys pending deletion
- IAM policies and roles
- Network interfaces

Useful commands:

```bash
aws elbv2 describe-load-balancers --region ap-south-1
aws elbv2 describe-target-groups --region ap-south-1
aws ec2 describe-instances --region ap-south-1
aws ec2 describe-volumes --region ap-south-1
aws rds describe-db-instances --region ap-south-1
aws rds describe-db-snapshots --region ap-south-1
aws ec2 describe-network-interfaces --region ap-south-1
```
