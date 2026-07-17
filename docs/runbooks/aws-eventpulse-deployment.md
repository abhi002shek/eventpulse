# AWS EventPulse Deployment Runbook

This runbook deploys the private EventPulse API to the existing AWS dev EKS
cluster and connects it to the existing private RDS PostgreSQL instance.

It does not create an ALB, Ingress, Route 53 record, ACM certificate, Argo CD or
monitoring stack.

## Prerequisites

- AWS CLI authenticated with `AWS_PROFILE=eventpulse-user`.
- Region `ap-south-1`.
- `kubectl` configured for EKS cluster `eventpulse-dev`.
- `helm` installed locally.
- Existing EKS cluster `eventpulse-dev`.
- Existing managed node group `eventpulse-dev-general`.
- Existing RDS instance `eventpulse-dev-postgres`.
- Existing Pod Identity association for namespace `eventpulse` and service
  account `eventpulse`.

Set environment:

```bash
export AWS_PROFILE=eventpulse-user
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

Verify identity:

```bash
aws sts get-caller-identity
```

The principal must not be account root.

Configure kubectl if needed:

```bash
aws eks update-kubeconfig --region ap-south-1 --name eventpulse-dev
```

## Pre-Deployment Checks

```bash
aws eks describe-cluster --name eventpulse-dev --query 'cluster.{Status:status,Version:version}'
aws eks describe-nodegroup --cluster-name eventpulse-dev --nodegroup-name eventpulse-dev-general
kubectl get nodes
aws rds describe-db-instances --db-instance-identifier eventpulse-dev-postgres
aws eks list-pod-identity-associations --cluster-name eventpulse-dev
```

RDS must be `available` and not publicly accessible. Nodes must be Ready.

## Install Secrets Store CSI And AWS Provider

```bash
ops/eks/install-secrets-provider.sh
```

The script installs the official EKS add-on
`aws-secrets-store-csi-driver-provider` pinned to `v3.1.1-eksbuild.2`. If the
add-on does not create `CSIDriver/secrets-store.csi.k8s.io`, it installs the
official Secrets Store CSI Driver Helm chart pinned to `1.6.0`.

The script does not read or print secret values.

## Install Kyverno And Policies

```bash
ops/eks/install-kyverno.sh
```

The script installs Kyverno chart `3.8.2`, applies EventPulse policies in Audit
mode, switches tested standard policies to Enforce, and applies signed-image
verification in Enforce mode.

## Deploy EventPulse

```bash
ops/eks/deploy-eventpulse.sh
```

The script discovers:

- RDS endpoint
- RDS port
- database name
- RDS-managed Secrets Manager secret ARN
- RDS private IP for NetworkPolicy egress

It passes non-secret values to Helm and never prints database credentials.

The Helm release uses:

```text
deploy/helm/eventpulse/values-aws-dev.yaml
```

Important Secret lifecycle behavior: the Secrets Store CSI Driver synchronizes
the Kubernetes Secret `eventpulse-database` only while a Pod mounts the
SecretProviderClass volume. The API, migration Job and seed Job all mount that
volume even though they consume credentials through environment variables.

## Validate EventPulse

```bash
ops/eks/validate-eventpulse.sh
```

The script verifies:

- Nodes are Ready.
- CSI driver and provider components exist.
- Kyverno is healthy.
- ServiceAccount, SecretProviderClass and synchronized Secret exist.
- Migration and seed Jobs completed.
- API Deployment rolled out.
- API Pods use the required immutable digest.
- API Pods run non-root with hardened security contexts and resources.
- NetworkPolicies exist.
- Signed-image fixture is admitted.
- Unsigned EventPulse fixture is rejected.
- `/health`, `/ready` and `/api/v1/events` return HTTP 200 through a temporary
  port-forward.

Secret values are not printed.

## Manual Private API Check

```bash
kubectl -n eventpulse port-forward svc/eventpulse 8000:8000
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/ready
curl http://127.0.0.1:8000/api/v1/events
```

Stop the port-forward when finished.

## Uninstall Workload Only

```bash
ops/eks/uninstall-eventpulse.sh
```

This removes the EventPulse Helm workload resources and synchronized Kubernetes
Secret. It does not delete:

- EKS cluster
- node group
- VPC
- NAT gateway
- RDS instance
- Secrets Manager secret
- Pod Identity association
- Terraform state
- optional Kyverno or CSI platform components

## Troubleshooting

Check Pods and events:

```bash
kubectl -n eventpulse get pods
kubectl -n eventpulse describe pod POD_NAME
kubectl -n eventpulse get events --sort-by=.metadata.creationTimestamp
```

Check jobs:

```bash
kubectl -n eventpulse get jobs
kubectl -n eventpulse logs job/eventpulse-migration
kubectl -n eventpulse logs job/eventpulse-seed
```

Check secret synchronization without revealing values:

```bash
kubectl -n eventpulse get secret eventpulse-database
```

If the Secret is missing, confirm that a Pod is mounting the
SecretProviderClass volume and that Pod Identity has permission to read only the
RDS-managed secret ARN.

## Known Limitations

- No public endpoint exists yet.
- `PGSSLMODE=require` is used; RDS CA verification is postponed.
- HPA is disabled until Metrics Server is installed and validated on EKS.
- Observability and GitOps are later milestones.
