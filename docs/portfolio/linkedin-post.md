I recently completed a major milestone in EventPulse, my DevOps and DevSecOps learning project.

EventPulse is a small event-booking API, but I used it to practice the full path from application code to a secure and observable AWS Kubernetes deployment.

What I built and validated:

- FastAPI and PostgreSQL booking API with transactional capacity protection
- Docker multi-stage non-root image
- GitHub Actions CI with Ruff, Mypy, Pytest, Gitleaks and Trivy
- SonarQube analysis on a trusted self-hosted runner
- GHCR image publishing with SBOM, GitHub provenance and Cosign keyless signing
- Helm and Kind validation
- Kyverno admission policy enforcement for signed images and workload controls
- AWS VPC, private EKS worker nodes and private RDS PostgreSQL
- Secrets Manager, Secrets Store CSI and EKS Pod Identity
- Public ALB for temporary validation access
- Prometheus, Grafana, Alertmanager, Fluent Bit and CloudWatch Logs
- Controlled resilience testing for Pod replacement and rollout recovery

One useful lesson came from observability. Prometheus correctly showed the EventPulse target as down because the live image did not yet contain the new `/metrics` endpoint. Instead of bypassing the check, I published a new signed image, updated the deployment digest and improved the validation script to check actual metric series.

The project is not presented as production traffic or a managed product. It is a practical learning platform for understanding how application development, supply-chain security, Kubernetes policy, AWS networking, managed databases and observability fit together.

Main takeaway: good platform engineering is not just provisioning resources. It is making the system understandable, verifiable and recoverable.
