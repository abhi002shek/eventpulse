# EventPulse Security Boundaries

This document explains the main security controls by layer and lists residual risks accepted for the dev/portfolio environment.

## GitHub Repository And Workflows

- Pull requests run CI and security workflows before merge.
- Workflows use least required permissions.
- Third-party actions are pinned to immutable commit SHAs.
- `pull_request_target` is not used for untrusted code.
- Publishing is separated from pull request validation.

## Dependency And Secret Scanning

- Gitleaks scans repository history and current changes.
- Trivy scans the repository filesystem and container image.
- SonarQube provides maintainability and quality-gate feedback.
- Fake example values are kept obvious; real secrets are not committed.

## Container Supply Chain

- Images are published to GHCR by immutable digest.
- Images include an SPDX SBOM and GitHub provenance.
- Cosign keyless signing ties the image to the trusted GitHub publishing workflow.
- Kubernetes deployment uses image digest references rather than `latest`.

## Kubernetes Admission

- Kyverno validates workload settings and image signatures.
- Policies cover digest requirements, non-root containers, security context, resource requests/limits and approved registries.
- Unsigned or incorrectly signed EventPulse images are rejected.

## AWS Identity And Secrets

- AWS IAM Identity Center is used for operator access.
- EKS Pod Identity grants AWS API access to specific Kubernetes service accounts.
- Secrets Manager stores database credentials.
- Secrets Store CSI syncs the secret into Kubernetes for the workload.
- KMS encrypts EKS secrets and RDS storage.

## Network And Runtime Boundaries

- Worker nodes run in private subnets with no public IPs.
- RDS PostgreSQL is private and not publicly accessible.
- Security groups restrict database access.
- Kubernetes NetworkPolicies restrict Pod ingress and egress.
- Containers run as non-root, drop Linux capabilities and use read-only root filesystems where compatible.
- Service-account token automounting is disabled unless required.
- EventPulse connects to RDS using TLS.

## Logging And PII

- Customer email is accepted for bookings but is not included in API responses.
- Application code must not log customer emails, tokens or passwords.
- Fluent Bit forwards application stdout logs to CloudWatch Logs.

## Residual Risks

- The public demo ALB uses HTTP without TLS.
- RDS is a dev-focused single-instance design, not a production HA database.
- One NAT Gateway is used to control cost.
- The EKS public endpoint is temporary and restricted during validation.
- Kubernetes Secret sync creates an etcd copy of the database password.
- Observability retention is short and dev-focused.
- Grafana is accessed by port-forward rather than a hardened public SSO endpoint.
- Terraform is manually applied; GitOps is intentionally postponed.
