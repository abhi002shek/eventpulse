# AWS Resume Environment Runbook

Use this runbook to rebuild the EventPulse AWS dev environment after a full workload destroy.

Resource IDs may change. Use Terraform outputs and discovery commands rather than old stored IDs.

## 1. AWS Profile And Identity

```bash
export AWS_PROFILE=eventpulse-user
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity
```

Stop if the principal is root.

## 2. Bootstrap State Bucket

Verify the Terraform state bucket still exists:

```bash
aws s3 ls | grep eventpulse-dev-terraform-state
```

Do not recreate bootstrap unless the state bucket was intentionally deleted.

## 3. Network Apply

```bash
cd infrastructure/terraform/environments/dev/network
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

## 4. EKS Apply

```bash
cd infrastructure/terraform/environments/dev/eks
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

Update kubeconfig using Terraform output:

```bash
terraform -chdir=infrastructure/terraform/environments/dev/eks output update_kubeconfig_command
```

## 5. Data Apply

```bash
cd infrastructure/terraform/environments/dev/data
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

Use outputs for database endpoint and secret ARNs. Do not paste them into documentation.

## 6. Platform Apply

```bash
cd infrastructure/terraform/environments/dev/platform
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

## 7. Observability Apply

```bash
cd infrastructure/terraform/environments/dev/observability
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

## 8. Cluster Add-Ons And Policies

Install required controllers and policies:

```bash
ops/eks/install-secrets-provider.sh
ops/eks/install-kyverno.sh
ops/eks/install-aws-load-balancer-controller.sh
```

Confirm Pods are ready:

```bash
kubectl get pods -A
```

## 9. EventPulse Deployment

Deploy EventPulse privately first:

```bash
ops/eks/deploy-eventpulse.sh
ops/eks/validate-eventpulse.sh
```

## 10. Public ALB

Enable temporary public validation access:

```bash
ops/eks/deploy-public-ingress.sh
ops/eks/validate-public-ingress.sh
```

Remove it when validation is complete:

```bash
ops/eks/remove-public-ingress.sh
```

## 11. Observability

Install and validate:

```bash
ops/eks/install-observability.sh
ops/eks/validate-observability.sh
ops/eks/run-resilience-tests.sh
```

## 12. Final Checks

```bash
kubectl -n eventpulse get pods,svc,ingress
kubectl -n monitoring get pods
kubectl -n amazon-cloudwatch get pods
```

Confirm:

- EventPulse Pods are Ready.
- `/health`, `/ready` and `/api/v1/events` return HTTP 200 during the demo window.
- Prometheus target is UP.
- CloudWatch logs are arriving.
- RDS remains private and encrypted.
