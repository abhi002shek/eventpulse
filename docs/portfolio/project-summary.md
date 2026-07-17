# EventPulse Project Summary

## Problem

EventPulse started as a learning project to show how a DevOps engineer can build, secure, package, deploy and operate a realistic application without hiding behind placeholder infrastructure. The application domain is event booking, which creates a useful transactional problem: customers must not be able to book more tickets than an event has available.

## Architecture

The application is a Python 3.12 FastAPI modular monolith backed by PostgreSQL. It exposes health, readiness, event and booking APIs. Bookings use database transactions and row-level locking to protect event capacity.

The platform evolved through local Docker Compose, secure container publishing, Kind/Helm validation and AWS EKS deployment. AWS hosts the transactional platform: VPC, private EKS nodes, private RDS PostgreSQL, Secrets Manager, Pod Identity, KMS, AWS Load Balancer Controller and CloudWatch Logs.

## Technical Decisions

- Use a modular monolith rather than microservices for the initial application.
- Use PostgreSQL row locking for booking capacity correctness.
- Publish immutable signed images to GHCR.
- Deploy by digest rather than mutable tags.
- Validate Kubernetes manifests locally before AWS.
- Use Kyverno for admission controls.
- Keep Grafana private through port-forwarding.
- Use AWS-managed RDS rather than in-cluster PostgreSQL for the AWS environment.

## Security Controls

- Gitleaks and Trivy in GitHub Actions.
- SonarQube for trusted main-branch analysis.
- SPDX SBOM and GitHub provenance.
- Cosign keyless signing.
- Kyverno signature and workload policy enforcement.
- Non-root containers, read-only root filesystem and dropped capabilities.
- Private worker nodes and private RDS.
- Secrets Manager, Secrets Store CSI and Pod Identity.
- KMS encryption for secrets and data.

## Reliability Controls

- Health and readiness probes.
- PostgreSQL readiness checks.
- Rolling updates.
- Two EventPulse API replicas.
- PodDisruptionBudget and HPA configuration.
- Prometheus metrics and alert rules.
- Grafana dashboards.
- CloudWatch application logs.
- Controlled resilience validation with Pod replacement and rollout recovery.

## Results

- 31 Pytest tests passed.
- 86.62% test coverage.
- EventPulse ran on private EKS worker nodes behind a public ALB.
- RDS was private, encrypted and available during validation.
- Prometheus target was UP after the metrics image was redeployed.
- Fluent Bit delivered EventPulse logs to CloudWatch Logs.
- Resilience validation passed.

## Trade-Offs

- Public demo uses HTTP because ACM/Route 53 were postponed.
- One NAT Gateway and single-instance RDS reduce cost but are not production HA.
- Terraform is applied manually to keep learning explicit before introducing Argo CD or automation.
- Grafana is private and accessed by port-forward rather than public SSO.

## What Was Learned

The project made the connections between application behavior, CI, image supply chain, Kubernetes policy, AWS networking, managed data services and observability concrete. The most useful lesson was that validation should fail when reality does not match intent: Prometheus correctly showed the EventPulse target down when the live image lacked `/metrics`, and the correct fix was to publish and redeploy a signed image rather than bypass monitoring.
