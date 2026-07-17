# EventPulse AWS Architecture

EventPulse is deployed as a FastAPI modular monolith on AWS EKS. The design is intentionally production-style but scoped for a portfolio/dev environment.

## Diagram

```mermaid
flowchart TB
  subgraph GitHub["GitHub"]
    Repo["Source repository"]
    CI["CI: Ruff, Mypy, Pytest"]
    Sec["Gitleaks and Trivy"]
    Sonar["Self-hosted SonarQube"]
    Publish["Secure image publishing"]
    GHCR["GHCR signed image"]
    SBOM["SPDX SBOM and provenance"]
    Repo --> CI
    Repo --> Sec
    Repo --> Sonar
    CI --> Publish
    Sec --> Publish
    Publish --> GHCR
    Publish --> SBOM
  end

  subgraph PublicAWS["AWS public layer"]
    Internet["Internet"]
    ALB["Public ALB, HTTP demo"]
    PublicSubnets["Public subnets, two AZs"]
    NAT["NAT Gateway"]
    Internet --> ALB
    PublicSubnets --> ALB
    PublicSubnets --> NAT
  end

  subgraph PrivateApp["Private application layer"]
    EKS["EKS private worker nodes"]
    App["EventPulse Pods"]
    Kyverno["Kyverno admission"]
    CSI["Secrets Store CSI"]
    LBC["AWS Load Balancer Controller"]
    Prom["Prometheus"]
    Grafana["Grafana"]
    Alertmanager["Alertmanager"]
    FluentBit["Fluent Bit"]
    EKS --> App
    EKS --> Kyverno
    EKS --> CSI
    EKS --> LBC
    EKS --> Prom
    EKS --> Grafana
    EKS --> Alertmanager
    EKS --> FluentBit
  end

  subgraph DataLayer["Isolated data layer"]
    RDS["Private RDS PostgreSQL"]
    DBSubnets["Isolated DB subnets"]
    Secrets["Secrets Manager"]
    KMS["KMS keys"]
    DBSubnets --> RDS
    Secrets --> KMS
    RDS --> KMS
  end

  subgraph Observability["Observability and security"]
    CW["CloudWatch Logs"]
    Rules["PrometheusRule alerts"]
    Dashboards["Grafana dashboards"]
    Terraform["Terraform states"]
  end

  ALB --> App
  App -->|"TLS database connection"| RDS
  App -->|"synced secret"| CSI
  CSI -->|"Pod Identity"| Secrets
  FluentBit --> CW
  Prom -->|"scrape /metrics"| App
  Prom --> Rules
  Grafana --> Prom
  Alertmanager --> Prom
  GHCR -->|"signed digest"| Kyverno
  Kyverno --> App
  Terraform --> PublicAWS
  Terraform --> PrivateApp
  Terraform --> DataLayer
```

## Main Components

- **GitHub** runs CI, security checks, SonarQube analysis and secure image publishing.
- **GHCR** stores the immutable signed EventPulse image.
- **AWS VPC** separates public ALB subnets, private EKS worker subnets and isolated RDS subnets.
- **EKS** runs EventPulse, Kyverno, Secrets Store CSI, AWS Load Balancer Controller and observability workloads.
- **RDS PostgreSQL** stores events and bookings in private subnets.
- **Secrets Manager** stores database credentials consumed through Secrets Store CSI and Pod Identity.
- **KMS** encrypts EKS secrets and RDS storage.
- **Prometheus/Grafana/Alertmanager** provide metrics, dashboards and alert evaluation.
- **Fluent Bit** forwards EventPulse application logs to CloudWatch Logs.

## Trust And Data Paths

- Public users reach EventPulse through the temporary HTTP ALB.
- The AWS Load Balancer Controller reconciles Kubernetes Ingress into ALB resources.
- ALB uses IP targets to route directly to EventPulse Pod IPs.
- EventPulse connects to private RDS PostgreSQL using TLS.
- Database credentials come from Secrets Manager through Pod Identity and Secrets Store CSI.
- Prometheus scrapes EventPulse `/metrics`.
- Fluent Bit tails container stdout and sends EventPulse logs to CloudWatch.
- Kyverno verifies the signed image digest before admission.
- Terraform manages AWS infrastructure through separated state scopes.

## Non-Goals In This Architecture

- No HTTPS, Route 53 or WAF yet.
- No Argo CD/GitOps yet.
- No public Grafana.
- No production traffic claim.
- No multi-cloud deployment yet.
