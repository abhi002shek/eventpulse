# Changelog

## v0.2.0

- Added AWS network foundation with VPC, public/private/isolated subnet layout and NAT path.
- Added EKS platform with private worker nodes, managed add-ons and KMS-backed secrets encryption.
- Added private RDS PostgreSQL, Secrets Manager integration and EKS Pod Identity.
- Deployed EventPulse to AWS EKS through Helm using signed immutable GHCR images.
- Added AWS Load Balancer Controller and temporary public ALB validation path.
- Added `/metrics`, structured request logging fields and Prometheus instrumentation.
- Added kube-prometheus-stack, Grafana dashboards, Alertmanager rules and Fluent Bit CloudWatch logging.
- Added resilience validation for Pod replacement, rollout recovery and replica restoration.
- Updated AWS values to deploy the v0.2.0 image digest.

## v0.1.0

- Added the base EventPulse FastAPI application.
- Added health, readiness, event and booking APIs.
- Added PostgreSQL, SQLAlchemy, Alembic and transactional booking capacity protection.
- Added Docker Compose local development workflow.
- Added multi-stage non-root Docker image.
- Added GitHub Actions CI and security workflows.
- Added Gitleaks, Trivy, Ruff, Mypy, Pytest and coverage gate.
- Added secure image publishing with GHCR, SBOM, provenance and Cosign keyless signing.
- Published the original signed EventPulse image.
