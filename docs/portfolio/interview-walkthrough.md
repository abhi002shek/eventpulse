# Interview Walkthrough

This is a 5-7 minute spoken walkthrough.

## Situation

EventPulse is a portfolio project I built to demonstrate DevOps, DevSecOps, Kubernetes and AWS platform engineering through a real application. I wanted something more realistic than static infrastructure, so I chose event booking because it has a transactional correctness problem: the system must not oversell tickets.

## Architecture

The application is a Python 3.12 FastAPI modular monolith backed by PostgreSQL. It exposes health, readiness, event and booking APIs. The AWS platform uses a VPC across two Availability Zones, private EKS worker nodes, private RDS PostgreSQL, Secrets Manager, Pod Identity and a public ALB for temporary demo access.

The delivery path starts in GitHub. Pull requests run CI, Gitleaks, Trivy and SonarQube analysis. The publishing workflow builds a Docker image, produces an SPDX SBOM and provenance, signs the image with Cosign keyless signing and publishes it to GHCR. Kubernetes deploys by immutable digest.

## Implementation

The app uses SQLAlchemy and Alembic for database access and migrations. Booking creation runs in one database transaction: it loads the Event by public UUID, locks the row, checks available capacity, creates the Booking, decrements capacity and commits both together.

The Kubernetes packaging is a Helm chart with ConfigMap and Secret separation, migration and seed Jobs, probes, HPA, PDB, NetworkPolicies and hardened security contexts. Local validation uses Kind before deploying to AWS.

## Security

The project has controls across the pipeline and runtime. GitHub Actions are pinned. Gitleaks scans for secrets. Trivy scans source and image. Images are signed and deployed by digest. Kyverno enforces image signature and workload security policies. AWS secrets are stored in Secrets Manager and accessed through Pod Identity and Secrets Store CSI. Worker nodes and RDS are private, and RDS storage is encrypted.

## Reliability

EventPulse has health and readiness endpoints, rolling updates, two API replicas, a PodDisruptionBudget and Prometheus metrics. Prometheus scrapes `/metrics`, Grafana shows request and latency dashboards, Alertmanager evaluates alert rules and Fluent Bit forwards logs to CloudWatch.

I also ran a controlled resilience test that deleted an API Pod, waited for replacement and rollout recovery, temporarily scaled down to one replica, restored two replicas and confirmed the API stayed healthy.

## Incident Or Blocker

A useful blocker happened during observability validation. Prometheus reported the EventPulse target as down with HTTP 404. The reason was that the live immutable image was older than the code in Git and did not include the new `/metrics` endpoint. The correct fix was not to weaken monitoring. I published a new signed image, updated the Helm digest, redeployed and then improved the validation script so it waits for target discovery and checks real request and latency metric series.

## Trade-Offs

This is a dev/portfolio environment, so some choices are intentionally not production-grade. The public ALB uses HTTP because Route 53, ACM and WAF are postponed. RDS is single-instance. One NAT Gateway is used to reduce cost. Grafana is accessed by port-forward. Argo CD is intentionally postponed until the manual Helm and Terraform workflow is well understood.

## Outcome

The result is a working end-to-end platform: application, tests, secure image supply chain, Kubernetes admission policies, AWS EKS deployment, private database, observability, logs and resilience validation. It demonstrates how I think through platform work: build something small, secure the path, validate behavior, document trade-offs and keep cost and teardown procedures explicit.
