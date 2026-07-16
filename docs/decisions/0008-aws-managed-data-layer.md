# 0008: AWS Managed Data Layer

## Context

EventPulse now has an AWS VPC, private application subnets, isolated database
subnets and an EKS cluster. The next AWS layer needs durable PostgreSQL storage
for the application without deploying the Helm release yet.

## Decision

Create a private Amazon RDS for PostgreSQL instance named
`eventpulse-dev-postgres` in `ap-south-1`.

The selected engine version is PostgreSQL `17.5`. It is currently reported by
RDS in `ap-south-1` as available, uses parameter group family `postgres17`, and
works with the cost-conscious `db.t4g.micro` instance class and `gp3` storage.
Newer PostgreSQL versions are available, but this milestone pins a stable
explicit minor version rather than floating automatically.

RDS is used instead of in-cluster PostgreSQL because AWS is the primary
transactional cloud for EventPulse, and managed backups, storage encryption,
patching integration and private subnet placement better match the target
platform than a self-managed database Pod.

The dev database is Single-AZ for cost. Production should use Multi-AZ or a more
resilient topology after workload and recovery requirements are understood.

## Alternatives Considered

- In-cluster PostgreSQL: retained only for local Kind validation, not for AWS
  transactional data.
- Aurora PostgreSQL: postponed because it adds cost and operational surface that
  is not needed for the first managed data layer.
- Multi-AZ by default: postponed for cost in the dev portfolio environment.
- Terraform-generated password: rejected for the preferred path because RDS can
  manage the master password in Secrets Manager without placing a password in
  variables, command lines or outputs.
- Automatic Secrets Manager rotation: postponed because correct RDS rotation
  requires a Lambda rotation function and network access that are outside this
  milestone.

## Security Implications

The database is placed only in isolated database subnets. Those subnets have no
default route to an Internet Gateway or NAT Gateway.

The RDS security group allows TCP `5432` only from the EKS workload security
group used by the current VPC CNI setup. It does not allow `0.0.0.0/0`, operator
public IPs, public subnets or the full VPC CIDR.

RDS storage encryption is enabled using the AWS-managed RDS KMS key for cost and
simplicity. This covers encrypted storage, automated backups, snapshots and log
storage associated with the instance.

TLS is enforced with the PostgreSQL parameter `rds.force_ssl = 1`. Application
clients should use `sslmode=require` at first and move to `verify-full` once CA
bundle handling is wired into the deployment.

The master password is managed by RDS in Secrets Manager. The secret value is
not output by Terraform. The initial EventPulse Pod Identity role is allowed to
read only the exact RDS-managed secret ARN. It does not receive broad
`secretsmanager:*`, S3 access or administrator permissions.

## Operational Implications

Automated backups are retained for seven days, enabling point-in-time recovery
inside that window. Backup retention must not be set to zero.

Deletion protection is enabled by default. Destroying the lab database requires
an intentional override and a final snapshot unless `skip_final_snapshot` is
explicitly changed for a disposable lab teardown.

The Secrets Store CSI Driver and AWS Secrets and Configuration Provider are not
installed by this Terraform state. The Helm chart is prepared to consume a
synced Kubernetes Secret and optional CSI mount, while the pinned cluster
component installation is documented for the next deployment milestone.

## Cost Implications

Costs come from RDS instance hours, `gp3` storage, backup storage beyond the
included allowance, Secrets Manager monthly secret charges, Secrets Manager API
calls and optional CloudWatch log exports. Existing EKS nodes, NAT and VPC costs
continue separately.

Stopping RDS can reduce instance-hour cost temporarily, but AWS may restart a
stopped DB instance after the service maximum stop period. Storage, backups,
snapshots and secrets continue to incur cost while retained.

## Limitations

The initial application secret is the RDS-managed master user secret. A separate
least-privilege database user should be introduced through a controlled
migration or operational procedure before production use.

Automatic password rotation is not enabled. RDS connectivity from EventPulse is
not live-validated until the Helm deployment milestone.

## Consequences

EventPulse gains a private AWS-managed PostgreSQL foundation with encrypted
storage, TLS enforcement, backups, deletion protection, Secrets Manager and EKS
Pod Identity integration, while keeping local Kind PostgreSQL behavior
available for development.
