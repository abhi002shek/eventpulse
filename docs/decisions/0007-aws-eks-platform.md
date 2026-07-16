# 0007: AWS EKS Platform

## Context

EventPulse needs an AWS Kubernetes foundation after the VPC and subnet baseline
from Milestone 6A. This milestone should create only the EKS platform layer, not
the application runtime, database, load balancers or GitOps tooling.

## Decision

Create an Amazon EKS cluster named `eventpulse-dev` in `ap-south-1` using
repository-owned Terraform resources.

The selected Kubernetes version is `1.36`. Amazon EKS reported this version as
the default version in standard support in `ap-south-1` on July 16, 2026, with
standard support ending on August 2, 2027.

The cluster uses private managed nodes in the existing private application
subnets. The public Kubernetes API endpoint remains enabled during bootstrap,
but access is restricted to an explicit operator CIDR, preferably the current
operator public IP as `/32`. The private endpoint is also enabled.

EKS access entries are used instead of manually editing `aws-auth`. The dev
operator principal receives the AWS-managed `AmazonEKSClusterAdminPolicy`
through an access policy association. Cluster creator admin permissions are
disabled so access is explicit.

One On-Demand managed node group named `eventpulse-dev-general` is created with
`t3.medium` instances, desired size 2, minimum size 1 and maximum size 3. Spot
capacity is postponed because early platform components need predictable
capacity while the cluster is being learned and validated.

The managed node launch template requires IMDSv2, disables public IP assignment,
uses an encrypted `gp3` root volume and does not configure SSH access.

The following EKS add-ons are managed with pinned versions:

- `vpc-cni`: `v1.21.2-eksbuild.2`
- `coredns`: `v1.14.2-eksbuild.4`
- `kube-proxy`: `v1.36.0-eksbuild.7`
- `eks-pod-identity-agent`: `v1.3.10-eksbuild.3`

## Alternatives considered

- Self-managed Kubernetes on EC2: rejected because EKS better matches the AWS
  platform objective and reduces undifferentiated control-plane operations.
- Public worker nodes: rejected because application workloads should run in
  private subnets.
- Private-only API endpoint from day one: postponed because the learning setup
  starts from an operator workstation outside the VPC.
- Spot nodes: postponed until the platform services and recovery workflow are
  better understood.
- External Terraform modules: rejected for this milestone to keep resource
  behavior visible to a DevOps learner.
- RDS, load balancer controllers and application deployment: postponed to later
  milestones.

## Security implications

The Kubernetes API public endpoint must never allow `0.0.0.0/0`. Terraform
validates that the configured public CIDRs are narrow. The operator should use
the current public IP as a `/32` and update it when their network changes.

Managed nodes run only in private application subnets and the launch template
does not assign public IPs. There is no SSH key pair or inbound SSH rule. Direct
node access should use SSM in a later milestone if it becomes necessary.

Node IAM permissions are limited to the AWS-managed policies required for EKS
worker node operation, ECR image pulls and initial VPC CNI operation. The node
role does not receive AdministratorAccess or broad S3 access.

The Pod Identity agent is installed so future workload IAM can move away from
node-wide permissions.

## Operational implications

The EKS cluster uses a separate Terraform remote-state key:
`eventpulse/dev/eks/terraform.tfstate`.

The network state is read from the existing Milestone 6A remote state. VPC and
subnet IDs are not hardcoded.

Control-plane logging is configurable. The dev defaults enable `api`, `audit`
and `authenticator` logs while leaving scheduler and controller manager logs
off to reduce cost and noise.

## Cost implications

Costs continue while the EKS control plane exists. Scaling nodes down does not
stop the EKS cluster hourly charge.

Expected cost sources include:

- EKS cluster hourly charge
- two `t3.medium` EC2 managed nodes by default
- encrypted `gp3` root volumes
- existing NAT gateway and its public IPv4 address
- NAT data processing
- CloudWatch log ingestion and retention

## Limitations

This milestone does not deploy EventPulse, RDS, ingress, certificates,
observability, Kyverno, Argo CD or CI deployment automation.

The design is a learning-oriented dev cluster, not a production high
availability reference architecture.

## Consequences

Operators must review the Terraform plan carefully before apply. They must
confirm that worker nodes are in private application subnets, the API public
CIDR is narrow and no existing network resources are replaced.

The IAM user access entry is an initial dev choice. A deployment role or AWS IAM
Identity Center role should replace it later.
