# 0010 - AWS Public Ingress

## Context

EventPulse is deployed privately on EKS and connects to private RDS. The next
portfolio milestone needs controlled public HTTP exposure without adding DNS,
TLS, ACM, Route 53, GitOps or observability.

## Decision

Install AWS Load Balancer Controller `v3.4.2` using Helm chart `3.4.2` from the
official AWS EKS Helm repository. Grant AWS permissions through EKS Pod Identity
for service account `kube-system/aws-load-balancer-controller`.

Expose EventPulse with a Kubernetes Ingress that creates an internet-facing ALB
on HTTP port 80 only. The EventPulse Service remains `ClusterIP`, and the ALB
uses target type `ip` so it routes to Pods through the VPC CNI.

## Alternatives Considered

- **Service type LoadBalancer**: rejected because Ingress gives clearer ALB
  annotations, health checks and future HTTPS migration.
- **NodePort exposure**: rejected because worker nodes remain private and should
  not receive public traffic directly.
- **Route 53 and ACM now**: postponed because no verified domain/certificate is
  available in this milestone.
- **Attaching permissions to the node role**: rejected in favor of a dedicated
  Pod Identity role.

## Security Implications

- No static AWS credentials are created.
- The controller has a dedicated IAM role and official controller IAM policy for
  the pinned controller version.
- Only TCP 80 is public initially.
- PostgreSQL remains private.
- Kubernetes API access is unchanged.
- Kyverno policies continue to protect EventPulse workload Pods.
- HTTP is temporary and not production safe for sensitive traffic.

## Operational Implications

The ALB is created and deleted by the controller based on the EventPulse
Ingress. Removing the Ingress should delete the ALB, but deletion can take a few
minutes.

## Cost Implications

The public ALB adds hourly Application Load Balancer charges, Load Balancer
Capacity Unit charges and data transfer charges. Existing EKS control plane,
EC2 worker node, NAT gateway and RDS costs continue.

## Limitations

- No HTTPS.
- No custom domain.
- No WAF or CloudFront.
- No automated GitOps deployment yet.

## Consequences

EventPulse can be validated from the public internet for portfolio
demonstration through an ALB DNS name. Production-grade exposure still requires
HTTPS, domain ownership, certificate management and a stricter edge design.
