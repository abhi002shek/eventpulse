# 0009 - EKS Workload Deployment

## Context

EventPulse now has a private AWS foundation: VPC networking, an EKS cluster with
private managed nodes, and an RDS PostgreSQL instance whose credentials are
managed by AWS Secrets Manager. The application image is published to GHCR by
immutable digest and signed through the trusted GitHub Actions publishing
workflow.

Milestone 6D deploys the EventPulse workload to EKS without creating public
application ingress.

## Decision

Deploy EventPulse with the existing Helm chart into the `eventpulse` namespace.
Use the signed immutable image digest:

```text
ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224
```

Use Amazon RDS PostgreSQL as the external database. The RDS endpoint, port and
database name are passed as non-secret Helm values at deployment time. Database
username and password are retrieved from Secrets Manager through Secrets Store
CSI Driver, AWS Secrets and Configuration Provider, and EKS Pod Identity.

Install Kyverno in the `kyverno` namespace. Apply EventPulse validation
policies in Audit mode first, then switch tested standard policies to Enforce.
Apply signed-image verification last in Enforce mode.

Keep the service private as a ClusterIP. Validate through `kubectl port-forward`
only.

## Alternatives Considered

- **Kubernetes Secret created manually from AWS CLI output**: rejected because it
  would increase the chance of printing or mishandling database credentials.
- **Hardcoded Secret ARN in committed Helm values**: rejected to keep
  environment-specific AWS identifiers out of reusable chart defaults.
- **External Secrets Operator**: postponed because Pod Identity plus Secrets
  Store CSI is enough for the current milestone.
- **Public ALB with TLS**: postponed until the ingress milestone.
- **Argo CD deployment**: postponed until the Helm deployment is validated
  manually.

## Security Implications

- No static AWS credentials are stored in Kubernetes or the repository.
- The application service account uses EKS Pod Identity and does not need a
  mounted Kubernetes API token.
- The synchronized Kubernetes Secret contains only `username` and `password`,
  not the complete Secrets Manager JSON payload.
- The Secret exists only while a Pod mounts the SecretProviderClass volume.
- RDS requires TLS, and the application receives `PGSSLMODE=require`.
- Kyverno verifies the EventPulse image digest and GitHub Actions keyless
  signature before admitting EventPulse workload Pods.
- NetworkPolicies remain default deny and allow only DNS and PostgreSQL egress
  needed by the API, migration Job and seed Job.

## Operational Implications

Deployment is intentionally ordered:

1. Namespace exists.
2. ServiceAccount exists.
3. SecretProviderClass exists.
4. Migration Job mounts the SecretProviderClass and runs Alembic.
5. Seed Job mounts the SecretProviderClass and inserts demo events.
6. API Deployment rolls out and mounts the SecretProviderClass.

The Secrets Store CSI synchronized Kubernetes Secret is not created merely by
installing the SecretProviderClass. At least one Pod must mount the CSI volume.

## Cost Implications

This milestone does not add load balancers, Route 53 records, ACM certificates,
RDS Proxy, monitoring stacks or additional cloud services beyond cluster
add-ons. Existing EKS, NAT gateway, worker nodes and RDS costs continue.

## Limitations

- The application is private and reachable only through Kubernetes networking or
  `kubectl port-forward`.
- `sslmode=require` encrypts the connection but does not validate the RDS host
  name. `verify-full` requires adding the RDS CA bundle to the runtime image in
  a later milestone.
- HPA is disabled for AWS dev until Metrics Server is installed and validated.
- Kyverno policies are focused on EventPulse workloads, not a full
  organization-wide policy baseline.

## Consequences

The deployment proves that the signed image can run privately on EKS against
private RDS using Pod Identity-backed secret retrieval. Public ingress, GitOps
and observability remain separate future milestones.
