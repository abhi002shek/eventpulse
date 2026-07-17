# Resume Bullets

- Designed and deployed EventPulse, a Python FastAPI event-booking application on AWS EKS with private worker nodes, public ALB validation access and private RDS PostgreSQL.
- Implemented transactional PostgreSQL booking capacity protection using SQLAlchemy, Alembic and row-level locking; validated behavior with 31 Pytest tests and 86.62% coverage.
- Built a secure container supply chain with GitHub Actions, GHCR, immutable image digests, SPDX SBOM, GitHub provenance and Cosign keyless signing.
- Enforced Kubernetes admission controls with Kyverno for signed images, non-root workloads, required resources and hardened security contexts.
- Integrated AWS Secrets Manager, Secrets Store CSI and EKS Pod Identity to avoid static cloud credentials and keep database credentials out of Git.
- Added Prometheus, Grafana, Alertmanager, Fluent Bit and CloudWatch Logs for metrics, dashboards, alert rules, application logs and resilience validation.
