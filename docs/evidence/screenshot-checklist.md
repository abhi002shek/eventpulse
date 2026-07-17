# Screenshot Checklist

Capture these screenshots from real tools only. Do not expose secrets, account IDs, secret ARNs, database endpoints, passwords, tokens or operator IP addresses.

## GitHub CI Successful

- **Filename:** `01-github-ci-success.png`
- **Visible:** PR or workflow run showing CI passed.
- **Hidden:** none usually required, but avoid repository secrets pages.
- **Why:** proves formatting, linting, typing, tests, coverage and image build passed.

## Security Workflow Successful

- **Filename:** `02-github-security-success.png`
- **Visible:** Gitleaks, Trivy filesystem and Trivy image jobs passed.
- **Hidden:** any detailed secret values if a log is open.
- **Why:** proves security checks gate pull requests.

## SonarQube Quality Gate

- **Filename:** `03-sonarqube-quality-gate.png`
- **Visible:** EventPulse project with quality gate status.
- **Hidden:** server tokens and administration pages.
- **Why:** proves maintainability analysis runs on trusted code.

## Secure Image Publishing

- **Filename:** `04-secure-image-publishing.png`
- **Visible:** publish workflow completed successfully.
- **Hidden:** workflow secrets and token values.
- **Why:** proves GHCR publishing, SBOM, provenance and signing workflow ran.

## GHCR Image Digest

- **Filename:** `05-ghcr-image-digest.png`
- **Visible:** EventPulse image package with immutable digest.
- **Hidden:** none usually required.
- **Why:** proves Kubernetes can deploy by digest rather than mutable tag.

## SBOM Artifact

- **Filename:** `06-sbom-and-provenance.png`
- **Visible:** SBOM/provenance artifacts or workflow summary.
- **Hidden:** none usually required.
- **Why:** proves supply-chain metadata was produced.

## Cosign Verification

- **Filename:** `07-cosign-verification.png`
- **Visible:** terminal command showing successful signature verification.
- **Hidden:** shell history containing tokens.
- **Why:** proves keyless signature verification works.

## EKS Nodes Ready

- **Filename:** `08-eks-nodes-ready.png`
- **Visible:** `kubectl get nodes` showing two Ready private worker nodes.
- **Hidden:** public operator IPs; node internal IPs are acceptable if needed but can be blurred.
- **Why:** proves EKS worker capacity exists across private nodes.

## EventPulse Pods Ready

- **Filename:** `09-eventpulse-pods-ready.png`
- **Visible:** `kubectl -n eventpulse get pods` showing two API Pods Ready.
- **Hidden:** none usually required.
- **Why:** proves the workload is running.

## Kyverno PolicyReports

- **Filename:** `10-kyverno-policyreports.png`
- **Visible:** `kubectl get policyreports -A` or policy results showing enforcement.
- **Hidden:** none usually required.
- **Why:** proves admission-policy validation exists.

## RDS Private, Encrypted And Available

- **Filename:** `11-rds-private-encrypted-available.png`
- **Visible:** RDS status Available, public access No, storage encrypted Yes.
- **Hidden:** database endpoint, account ID and secret ARN.
- **Why:** proves the data layer is private and encrypted.

## ALB Targets Healthy

- **Filename:** `12-alb-targets-healthy.png`
- **Visible:** target group with both EventPulse targets Healthy.
- **Hidden:** account ID if visible.
- **Why:** proves ALB routes to healthy Pod IP targets.

## Public API Health And Events

- **Filename:** `13-public-api-health-events.png`
- **Visible:** `/health`, `/ready` and `/api/v1/events` returning HTTP 200.
- **Hidden:** temporary ALB DNS if the screenshot will be public after teardown.
- **Why:** proves the app was reachable during the demo window.

## Prometheus EventPulse Target UP

- **Filename:** `14-prometheus-target-up.png`
- **Visible:** Prometheus target page showing EventPulse target `UP`.
- **Hidden:** none usually required.
- **Why:** proves metrics scraping works.

## Grafana EventPulse Dashboard

- **Filename:** `15-grafana-eventpulse-dashboard.png`
- **Visible:** request and latency panels with data.
- **Hidden:** Grafana admin password or session tokens.
- **Why:** proves dashboard provisioning and metrics visualization.

## CloudWatch Application Logs

- **Filename:** `16-cloudwatch-logs.png`
- **Visible:** log group and EventPulse `/health` or `/ready` log events.
- **Hidden:** account ID and any accidental sensitive fields.
- **Why:** proves Fluent Bit delivered application logs.

## Resilience Test Output

- **Filename:** `17-resilience-test-output.png`
- **Visible:** Pod deletion/replacement, rollout recovery, scale down/up and success message.
- **Hidden:** none usually required.
- **Why:** proves controlled recovery validation.

## Terraform No-Change Plans

- **Filename:** `18-terraform-no-change-plan.png`
- **Visible:** Terraform plan showing no changes for validated states.
- **Hidden:** backend bucket names or account ID if publishing publicly.
- **Why:** proves applied AWS infrastructure matched configuration at validation time.
