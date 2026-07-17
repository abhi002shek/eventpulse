# AWS Public ALB Runbook

This runbook exposes the private EventPulse EKS deployment through a temporary
internet-facing Application Load Balancer on HTTP port 80.

HTTP is temporary for portfolio validation only. Production requires HTTPS.

## Prerequisites

- AWS profile `eventpulse-user`.
- Region `ap-south-1`.
- EKS cluster `eventpulse-dev` active.
- Two EventPulse Pods Ready in namespace `eventpulse`.
- EventPulse Service remains `ClusterIP`.
- Private RDS `eventpulse-dev-postgres` available.
- Kyverno installed and enforcing EventPulse policies.

Set:

```bash
export AWS_PROFILE=eventpulse-user
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

## Terraform Platform State

Initialize the platform state:

```bash
cd infrastructure/terraform/environments/dev/platform
terraform init \
  -backend-config='bucket=eventpulse-dev-terraform-state-ACCOUNT_ID-ap-south-1'
```

Plan:

```bash
terraform plan -out=tfplan
```

The plan should create only:

- AWS Load Balancer Controller IAM policy
- AWS Load Balancer Controller IAM role
- EKS Pod Identity association for `kube-system/aws-load-balancer-controller`

Apply only after reviewing the plan:

```bash
terraform apply tfplan
```

Do not commit `tfplan`.

## Install Controller

```bash
ops/eks/install-aws-load-balancer-controller.sh
```

The script installs official chart `eks/aws-load-balancer-controller` version
`3.4.2` with app image tag `v3.4.2`. It reuses service account
`kube-system/aws-load-balancer-controller` and the Terraform-created Pod
Identity association.

## Deploy Public Ingress

```bash
ops/eks/deploy-public-ingress.sh
```

The script keeps the Service as `ClusterIP`, enables the Helm Ingress, waits for
an ALB DNS name and waits for target health.

## Validate

```bash
ops/eks/validate-public-ingress.sh
```

It verifies:

- controller rollout
- Ingress annotations
- ALB scheme `internet-facing`
- target type `ip`
- public subnet placement
- healthy targets
- public `/health`, `/ready` and `/api/v1/events`
- RDS remains private

## Remove Public Exposure

```bash
ops/eks/remove-public-ingress.sh
```

This deletes only the EventPulse Ingress and waits for ALB deletion. The
controller, EKS, RDS and EventPulse private workload remain.

To remove the controller Helm release too:

```bash
REMOVE_CONTROLLER=true ops/eks/remove-public-ingress.sh
```

IAM resources remain Terraform-managed.

## Cost Warning

ALB hourly, LCU and data transfer charges continue while the ALB exists. Remove
the Ingress when public validation is finished.

Existing EKS, EC2 worker node, NAT gateway and RDS costs are separate and remain
until those resources are scaled down or destroyed through their own runbooks.
