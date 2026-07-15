# 0002 Self-Hosted SonarQube Architecture

## Context

EventPulse already has GitHub Actions CI, Ruff, Mypy, PostgreSQL-backed Pytest tests, a 70% coverage gate, Docker image validation, Gitleaks, and Trivy filesystem and image scans.

Milestone 3C adds SonarQube Community Build for portfolio-oriented code quality analysis. Community Build is useful for static analysis and quality gates, but it is not the primary pre-merge security gate for this public repository.

## Decision

Run SonarQube Community Build on one temporary Ubuntu EC2 instance using Docker Compose. The same host will later run a GitHub Actions self-hosted runner, but runner installation is postponed until SonarQube is verified.

SonarQube complements existing CI and security scans. Existing CI, Gitleaks, and Trivy remain the pre-merge gates.

Community Build analysis will run only for trusted `main` branch code and manual dispatch. A public-repository pull request will never run on the self-hosted runner.

The SonarQube UI will not be publicly exposed. It will bind to `127.0.0.1:9000` and be reached through SSH port forwarding. The SonarQube PostgreSQL database will be private to the Compose network and will not publish a host port.

## Alternatives Considered

- SonarQube Cloud: simpler operations, but less useful for learning self-hosted operations.
- Long-running production SonarQube: unnecessary cost and operational burden for this portfolio phase.
- Terraform-managed AWS infrastructure now: postponed until manual setup is understood.
- Kubernetes deployment: postponed because this milestone is about a temporary EC2-hosted service, not cluster operations.
- Public reverse proxy with TLS: postponed to avoid exposing SonarQube publicly before there is a stronger operational need.

## Security Implications

The self-hosted runner is risky for a public repository if it executes pull-request code. The workflow must not use `pull_request` triggers on this runner.

No AWS credentials, SonarQube tokens, runner registration tokens, runner removal tokens, database passwords, or SSH private keys may be committed.

SonarQube database credentials live only in an ignored server-side `.env.sonar` file with restrictive permissions.

The deployment uses exact image tags plus linux/amd64 digests. The containers do not use privileged mode, host networking, or Docker socket mounts.

## Operational Implications

The EC2 host needs SonarQube and Elasticsearch Linux settings such as `vm.max_map_count`, `fs.file-max`, file-descriptor limits, and process limits.

Docker Compose named volumes hold SonarQube data, logs, extensions, and PostgreSQL data. Operators must avoid destructive volume cleanup commands unless intentionally resetting the service.

The SonarQube UI is accessed through an SSH tunnel. If the EC2 instance is stopped and started, the public IP may change and the SSH security-group source IP should be rechecked.

## Cost Implications

Stopping the EC2 instance when not demonstrating reduces compute cost, but EBS storage charges continue while stopped.

Snapshots may add storage cost and should be cleaned up when no longer needed.

The single-instance design minimizes cost and complexity for a learning project.

## Limitations

The current deployment is intentionally single-instance and not highly available.

SonarQube Community Build is not treated as a full pull-request decoration or branch analysis platform for this project.

The service is not public, has no reverse proxy, and has no TLS endpoint.

The setup is not yet codified in Terraform.

## Consequences

EventPulse gains a reusable SonarQube server deployment package without changing application code or cloud infrastructure yet.

The project can demonstrate secure operational setup, image pinning, private service networking, local-only UI exposure, and clear cleanup procedures.

Future phases can add the self-hosted runner, main-branch Sonar workflow, project analysis properties, and eventually Terraform after the manual operating model is understood.
