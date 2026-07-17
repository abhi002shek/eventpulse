# 0011 AWS EKS Observability

## Context

EventPulse now runs on AWS EKS with a public AWS Load Balancer Controller ingress, private RDS PostgreSQL and hardened Kubernetes workloads. The project needs observability that helps a DevOps learner understand application health, Kubernetes health and operational failure modes without adding a managed production observability platform too early.

## Decision

Use kube-prometheus-stack on EKS for Prometheus, Alertmanager, Grafana, kube-state-metrics and node-exporter. EventPulse exposes Prometheus metrics at `/metrics`, and the Helm chart renders a ServiceMonitor and PrometheusRule when monitoring is enabled.

Use AWS for Fluent Bit to forward Kubernetes application logs to CloudWatch Logs. Fluent Bit uses EKS Pod Identity and a Terraform-managed least-privilege IAM role. No static AWS credentials are stored in Kubernetes or source code.

Grafana, Prometheus and Alertmanager remain ClusterIP-only. Operators access Grafana through `kubectl port-forward`.

## Alternatives Considered

- CloudWatch metrics only: simpler AWS-native setup, but weaker for Kubernetes-native ServiceMonitor and PrometheusRule learning.
- Loki for logs: keeps logs inside the cluster, but adds memory/storage pressure to the small dev EKS environment.
- OpenSearch: powerful but too costly and operationally heavy for this phase.
- Public Grafana: convenient but unnecessary risk without HTTPS, SSO and network restrictions.

## Security Implications

The monitoring UIs are not publicly exposed. Fluent Bit uses Pod Identity rather than static credentials. CloudWatch log permissions are scoped to the EventPulse application log group. The logging pipeline must never include database passwords, tokens or customer emails.

## Operational Implications

Prometheus and Grafana consume CPU and memory on the dev nodes, so retention is intentionally short. Alert rules are learning-focused and should be tuned after real measurements. CloudWatch Logs retention is short to limit cost.

## Cost Implications

Prometheus/Grafana run on existing EKS nodes and increase node resource usage. CloudWatch Logs charges for ingestion and retention, so retention starts at seven days. The stack should be uninstalled when not needed for learning or demos.

## Limitations

This is not a highly available observability architecture. Alertmanager notifications are not wired to email, Slack or PagerDuty yet. Grafana has no public HTTPS endpoint. No long-term metrics storage is configured.

## Consequences

EventPulse gains request metrics, booking outcome metrics, database readiness metrics, Kubernetes workload visibility, alert rules and CloudWatch application logs. Later milestones can add alert routing, longer retention, managed observability or GitOps after the manual workflow is understood.
