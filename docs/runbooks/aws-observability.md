# AWS Observability Runbook

This runbook installs and validates EventPulse observability on the dev EKS cluster.

## Prerequisites

- AWS profile: `eventpulse-user`
- Region: `ap-south-1`
- EKS cluster: `eventpulse-dev`
- EventPulse release already deployed with public ALB ingress
- Tools: `aws`, `kubectl`, `helm`, `terraform`, `curl`, `python3`

Export the usual environment:

```bash
export AWS_PROFILE=eventpulse-user
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

## Terraform

The observability Terraform environment creates:

- CloudWatch Logs group: `/aws/eks/eventpulse-dev/eventpulse/application`
- IAM role for AWS for Fluent Bit
- IAM policy scoped to the EventPulse log group
- EKS Pod Identity association for the `amazon-cloudwatch/aws-for-fluent-bit` service account

Initialize and apply:

```bash
cd infrastructure/terraform/environments/dev/observability
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
rm -f tfplan
cd -
```

Do not commit `backend.hcl`, `tfplan`, `.terraform/` or state files.

## Install

```bash
ops/eks/install-observability.sh
```

The script installs:

- kube-prometheus-stack chart `87.17.0`
- Prometheus app version `v0.92.1`
- aws-for-fluent-bit chart `0.2.0`
- Fluent Bit app version `3.2.1`

## Validate

```bash
ops/eks/validate-observability.sh
```

The script checks:

- EventPulse ServiceMonitor and PrometheusRule exist
- Prometheus is ready and sees EventPulse metrics
- Alert rules are loaded
- Grafana, Prometheus and Alertmanager are ClusterIP-only
- Fluent Bit Pods are running
- CloudWatch log group and streams exist
- Public `/health`, `/ready` and `/api/v1/events` still return success

## Grafana Access

Grafana is not public. Use port forwarding:

```bash
kubectl -n monitoring port-forward service/eventpulse-observability-grafana 3000:80
```

Open:

```text
http://127.0.0.1:3000
```

Get the generated admin password without printing it into shared notes:

```bash
kubectl -n monitoring get secret eventpulse-observability-grafana \
  -o jsonpath='{.data.admin-password}' | base64 --decode
```

## Logs

CloudWatch log group:

```text
/aws/eks/eventpulse-dev/eventpulse/application
```

Use the AWS Console or:

```bash
aws logs describe-log-streams \
  --log-group-name /aws/eks/eventpulse-dev/eventpulse/application \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

Do not copy customer emails, tokens or passwords into tickets or docs.

## Controlled Resilience Checks

```bash
ops/eks/run-resilience-tests.sh
```

The script deletes one API Pod, waits for the Deployment to recover, temporarily scales the API down to one replica, checks public health/readiness, and restores the original replica count.

## Uninstall

```bash
ops/eks/uninstall-observability.sh
```

This removes the Helm releases and dashboard ConfigMaps. It does not destroy Terraform-managed CloudWatch or IAM resources. Destroy those only when intentionally cleaning up the observability AWS layer.

## Cost Notes

Prometheus/Grafana consume node resources. CloudWatch Logs charges for ingestion and retained data. The Terraform log group retention is seven days by default.
