# EventPulse Project Retrospective

## What Went Well

- The project grew in small milestones, which kept each layer understandable.
- The application stayed a modular monolith instead of becoming unnecessary microservices.
- Booking capacity protection was solved with PostgreSQL transactions and locking rather than optimistic placeholder logic.
- CI, security scanning, signed images, Kubernetes policies and AWS deployment were all validated incrementally.
- Documentation and runbooks were created close to the implementation, which made later debugging easier.

## Key Technical Decisions

- Use FastAPI and PostgreSQL for a realistic but approachable application.
- Use SQLAlchemy and Alembic rather than direct SQL strings in application code.
- Publish immutable signed images to GHCR.
- Use Helm first, postpone Argo CD until manual deployment is understood.
- Use RDS for AWS rather than in-cluster PostgreSQL.
- Use Secrets Manager, Pod Identity and Secrets Store CSI rather than static credentials.
- Keep Grafana private and expose it only through port-forwarding.

## Failures Encountered

- Trivy blocked a vulnerable application dependency, which forced dependency correction instead of ignoring the finding.
- SonarQube self-hosted runner setup initially failed due to directory permissions.
- Kyverno CLI tests failed because the test manifest used fields incompatible with the installed CLI schema.
- An EKS public endpoint security finding required tighter CIDR handling and documentation.
- AWS EKS secrets encryption using KMS was added after reviewing platform security controls.
- Codex sandbox DNS could not resolve the EKS endpoint while the host environment could, so live validation required explicit network access.
- Prometheus marked the EventPulse target down with HTTP 404 because the live image did not yet contain `/metrics`.

## Corrections Made

- Dependency versions were adjusted rather than weakening Trivy policy.
- SonarQube host setup was corrected and documented.
- Kyverno tests were updated to match the installed CLI schema.
- EKS endpoint restrictions and operational notes were updated.
- KMS encryption was added for EKS secrets.
- A new signed EventPulse image was published and redeployed with `/metrics`.
- The observability validation script was improved to wait for Prometheus target discovery and verify actual request and latency metric series.

## Security Findings

- The public demo ALB currently uses HTTP and should not be treated as production-ready.
- The Kubernetes synced Secret creates a copy of the database password in etcd, even though Secrets Manager remains the source of truth.
- The dev platform uses cost-conscious availability choices such as single-instance RDS and one NAT Gateway.
- The public EKS endpoint is temporary and restricted, but a private endpoint would be preferable for production.

## Cost Trade-Offs

- One NAT Gateway controls cost but reduces availability.
- Single-instance RDS controls cost but is not highly available.
- Short CloudWatch retention controls log cost.
- The public ALB should be removed outside validation windows.
- The teardown runbook retains the Terraform state bucket unless the project is permanently deleted.

## What Would Change For Production

- Add HTTPS with ACM and Route 53.
- Add WAF and stricter edge protections.
- Use multi-AZ RDS and tested backup/restore procedures.
- Consider private-only EKS endpoint access through VPN or bastion patterns.
- Add alert routing to an operations channel.
- Add GitOps promotion with Argo CD after Helm workflows are stable.
- Add stronger environment separation and least-privilege operator roles.
- Define real SLOs from measured production traffic rather than learning targets.

## Next Phase Possibilities

- HTTPS and DNS.
- WAF and edge hardening.
- GitOps with Argo CD.
- Longer-term observability and log analytics.
- Google Cloud asynchronous analytics.
- Performance testing and measured SLO refinement.
