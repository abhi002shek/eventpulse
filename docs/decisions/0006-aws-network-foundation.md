# 0006: AWS Network Foundation

## Context

EventPulse is moving from local and Kubernetes packaging work into AWS
infrastructure. AWS is the primary transactional cloud for the project, but the
first AWS milestone should stay small and understandable.

## Decision

Create a Terraform bootstrap stack and a reusable network module for the dev
environment in `ap-south-1`.

The bootstrap stack creates an S3 bucket for Terraform remote state and a
customer managed KMS key for state encryption. It uses S3 native lock files
through Terraform backend setting `use_lockfile = true`. DynamoDB locking is not
created.

The dev network creates:

- a custom VPC instead of using the default VPC
- two public subnets that do not automatically assign public IPv4 addresses
- two private application subnets
- two isolated private database subnets
- one Internet Gateway
- one NAT gateway for dev private application egress
- route tables and associations
- future-compatible EKS subnet role tags

EKS, RDS, load balancers and application deployments are postponed.

## Alternatives considered

- Default VPC: rejected because it does not demonstrate deliberate network
  design and separation.
- Three Availability Zones: postponed to reduce NAT and subnet complexity for
  the learning-focused dev environment.
- One NAT gateway per Availability Zone: more resilient, but rejected for dev
  because it increases hourly cost.
- DynamoDB state locking: rejected because Terraform S3 native lock files are
  simpler for this milestone.
- Terraform Cloud: postponed to keep state ownership and workflow visible.

## Trade-offs

One NAT gateway is a cost-conscious dev compromise. It avoids the cost of one
NAT gateway per Availability Zone, but it is not highly available across AZs.
This is acceptable for the portfolio dev environment and should be revisited
before any production design.

Database subnets are isolated and have no default route to the Internet Gateway
or NAT gateway. This makes future private RDS placement clearer.

## Consequences

Terraform users must bootstrap state before initializing the dev network stack
with the S3 backend.

Destroying the bootstrap bucket is intentionally protected and requires
exceptional care because it contains Terraform state history.

Manual review and explicit approval are required before any `terraform apply`.
