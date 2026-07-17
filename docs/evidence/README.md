# EventPulse Evidence

This folder describes what evidence to capture for the completed EventPulse AWS development platform.

Do not create fake evidence. Screenshots and command outputs should be captured from real GitHub, AWS, Kubernetes, Prometheus, Grafana, CloudWatch and terminal sessions.

## Evidence Rules

- Hide AWS account IDs, operator IPs, secret ARNs, database endpoints, passwords and tokens.
- Prefer screenshots that show status and resource names without revealing credentials.
- Use point-in-time language. These screenshots prove validation at capture time, not permanent availability.
- Do not commit binary screenshots unless intentionally maintaining an evidence archive in Git.

## Recommended Folder

```text
docs/evidence/milestone-6g/
  01-github-ci-success.png
  02-github-security-success.png
  03-sonarqube-quality-gate.png
  04-secure-image-publishing.png
  05-ghcr-image-digest.png
  06-sbom-and-provenance.png
  07-cosign-verification.png
  08-eks-nodes-ready.png
  09-eventpulse-pods-ready.png
  10-kyverno-policyreports.png
  11-rds-private-encrypted-available.png
  12-alb-targets-healthy.png
  13-public-api-health-events.png
  14-prometheus-target-up.png
  15-grafana-eventpulse-dashboard.png
  16-cloudwatch-logs.png
  17-resilience-test-output.png
  18-terraform-no-change-plan.png
```

## Supporting Documents

- [Screenshot checklist](screenshot-checklist.md)
- [Validation summary](validation-summary.md)
