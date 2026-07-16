# 0004 Kubernetes Packaging And Security

## Context

EventPulse has a verified container image in GitHub Container Registry. The next step is to package the application for Kubernetes in a way that is understandable, repeatable and secure before introducing cloud infrastructure.

This milestone targets local validation with Kind. It must not create AWS, GCP, EKS, GKE, Terraform, Argo CD or cloud credentials.

## Decision

Use a first-party Helm chart at `deploy/helm/eventpulse` for Kubernetes packaging.

The chart deploys the EventPulse API by immutable digest:

```text
ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224
```

The chart includes local-only PostgreSQL resources for Kind validation. This in-cluster PostgreSQL deployment is temporary and is expected to be replaced by AWS RDS in the AWS milestone.

Kind is used before EKS to reduce cost, shorten feedback loops and make Kubernetes behavior visible on a local workstation.

## Alternatives Considered

- Raw Kubernetes YAML: simple at first, but harder to parameterize safely across local and future environments.
- Kustomize: useful for overlays, but Helm is a better fit here because we need value validation, hooks and reusable chart packaging.
- Cloud Kubernetes immediately: postponed to avoid paying for infrastructure and debugging cloud-specific concerns before the Kubernetes package is proven locally.
- Argo CD immediately: postponed until the Helm chart is validated and stable.
- Kyverno immediately: postponed to Milestone 5B so policy enforcement is introduced after the baseline chart exists.

## Security Implications

Immutable digest deployment is mandatory. Tags such as `latest`, `v0.1.0` alone and local image names are not sufficient.

The API runs as a non-root UID, disables privilege escalation, drops all Linux capabilities, uses `seccompProfile: RuntimeDefault`, uses a read-only root filesystem and disables automatic service-account token mounting.

The application ServiceAccount has no Role or ClusterRole because EventPulse does not need Kubernetes API access.

ConfigMap values and Secret values are separated. Real database passwords must not be committed.

NetworkPolicies use default-deny ingress and egress, then allow only namespace-local API ingress, API and Job egress to PostgreSQL, DNS egress and PostgreSQL ingress from the API, migration Job and seed Job.

Image pulls happen through the node runtime before Pod NetworkPolicies apply. NetworkPolicy controls application Pod traffic after scheduling.

## Operational Implications

The migration and seed Jobs run as ordered Helm post-install/post-upgrade hooks. Migration has lower hook weight than seed, so seed data is inserted only after the schema migration succeeds. This allows local PostgreSQL to be created by the same release before migrations run, and a failed hook prevents a successful deployment workflow.

The seed Job is optional and disabled by default. The local Kind deployment script enables it for demonstration data.

The chart creates an HPA by default, but CPU scaling cannot be fully validated unless metrics-server is installed. The Kind script does not install metrics-server yet because this milestone avoids adding another externally managed component.

Topology spreading uses hostname spreading with `ScheduleAnyway` so single-node Kind clusters do not leave replicas pending. EKS can later use stronger zone and hostname spreading.

## Cost Implications

Kind validation runs locally and avoids cloud spend. The local PostgreSQL PVC uses workstation storage only.

## Limitations

This milestone does not include EKS, GKE, Terraform, Argo CD, Kyverno, Ingress, public TLS, cloud load balancers or External Secrets.

The local PostgreSQL deployment is not a production database architecture.

The Kind cluster is not highly available and does not model every cloud networking behavior.

## Consequences

EventPulse gains a repeatable Kubernetes package with strong default security controls and local validation scripts.

Future milestones can build on this chart for policy enforcement, GitOps and cloud deployment without redesigning the application.
