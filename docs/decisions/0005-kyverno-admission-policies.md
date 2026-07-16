# 0005: Kyverno Admission Policies

## Context

EventPulse already has CI checks, Trivy scans, signed GHCR images and a local
Kind Helm deployment. Those checks happen before deployment, but Kubernetes can
still accept unsafe manifests if someone applies them directly to the cluster.

## Decision

Use Kyverno in the local Kind cluster to validate EventPulse workloads at
admission time.

The first policy set uses Audit mode for standard workload controls:

- disallow floating image tags such as `latest`
- require immutable `sha256` image digests
- require non-root containers
- require hardened container security contexts
- require CPU and memory requests and limits
- restrict EventPulse application images to the approved GHCR repository

The signed-image policy uses Enforce mode for the EventPulse image path:

- image path: `ghcr.io/abhi002shek/eventpulse*`
- issuer: `https://token.actions.githubusercontent.com`
- identity: `https://github.com/abhi002shek/eventpulse/.github/workflows/publish-image.yml@refs/heads/main`

## Alternatives considered

- Kubernetes Pod Security Admission only: useful baseline, but it does not
  verify Cosign signatures or enforce project-specific registry rules.
- Gatekeeper: strong policy engine, but Kyverno policies are YAML-native and
  easier to understand for this learning milestone.
- Enforce all policies immediately: rejected because a bad admission policy can
  block normal cluster operations and slow learning.

## Security implications

Kyverno admission webhooks can reject unsafe resources before they run. This is
stronger than CI alone because it protects the cluster at deployment time.

System namespaces are excluded so Kyverno, CoreDNS and Kind infrastructure do
not get blocked by EventPulse-specific rules.

Digest verification and signature verification are different controls. A digest
proves the exact image bytes. A signature proves who signed those bytes and
which trusted identity produced the image.

## Operational implications

Audit mode is used first so violations appear in PolicyReports without breaking
deployments. After the reports are reviewed, selected standard policies can be
switched to Enforce mode in the local cluster.

If a webhook blocks cluster operations, recovery is to remove the problematic
policy first. If the webhook itself is unhealthy, uninstall the Kyverno release
from the Kind cluster.

## Cost implications

Kyverno runs only in the local Kind environment for this milestone, so there is
no cloud cost.

## Limitations

This milestone does not configure EKS, Argo CD, Terraform, cloud admission
controls or production high availability for Kyverno.

Offline Kyverno CLI tests validate policy structure and standard rules. Live
signature verification requires network access to GHCR and Sigstore services.

## Consequences

EventPulse gains a local admission-control feedback loop before moving to EKS.
The policies document what the future cluster should reject and give a safer
path from Audit to Enforce.
