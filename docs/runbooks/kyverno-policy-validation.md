# Kyverno Policy Validation Runbook

This runbook validates EventPulse admission policies in the local Kind cluster.

## Prerequisites

- Kind cluster from `ops/kind/create-cluster.sh`
- EventPulse deployed with `ops/kind/deploy.sh`
- `kubectl`
- `helm`
- optional: `kyverno` CLI for offline policy tests
- optional: `kubeconform` for rendered manifest schema validation

## Install Kyverno

```bash
ops/kind/install-kyverno.sh
```

The script installs Kyverno chart `3.8.2` in namespace `kyverno` and waits for
the admission, background, cleanup and reports controllers.

## Validate Policies

```bash
ops/kind/validate-kyverno.sh
```

The script:

- applies Audit policies
- creates valid and deliberately invalid fixtures
- inspects PolicyReports
- runs `kyverno test policies/kyverno/tests` when the Kyverno CLI is installed
- switches selected standard policies to Enforce in the local cluster
- proves a latest-tag image is rejected
- applies the signed-image verification policy
- proves the signed EventPulse image is admitted
- proves an unsigned or untrusted EventPulse image is rejected

## Inspect PolicyReports

```bash
kubectl -n eventpulse get policyreports
kubectl -n eventpulse describe policyreport polr-ns-eventpulse
```

PolicyReports are the main way to learn from Audit mode. They show what would
be rejected later without blocking the current deployment.

## Test A Rejection

```bash
kubectl apply --dry-run=server \
  -f policies/kyverno/tests/resources/invalid-latest-image.yaml
```

After the standard policies are switched to Enforce, this command should fail.

## Verify Image Signatures

Kyverno verifies the EventPulse image with Sigstore keyless identity:

- issuer: `https://token.actions.githubusercontent.com`
- identity: `https://github.com/abhi002shek/eventpulse/.github/workflows/publish-image.yml@refs/heads/main`

The image must also be deployed by digest:

```text
ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224
```

A digest pins the exact image bytes. A signature proves that a trusted GitHub
Actions workflow signed those bytes.

## Webhook Recovery

Admission webhooks sit in the Kubernetes write path. A bad policy can block new
resources.

For a bad EventPulse policy:

```bash
kubectl delete -f policies/kyverno/enforce --ignore-not-found
kubectl delete -f policies/kyverno/audit --ignore-not-found
```

For a broken local Kyverno installation:

```bash
ops/kind/uninstall-kyverno.sh
```

Do not delete CRDs casually. Removing Kyverno CRDs also removes policy and
report custom resources.

## Uninstall

```bash
ops/kind/uninstall-kyverno.sh
```

This removes the Kyverno Helm release and EventPulse policy resources. It does
not delete the Kind cluster.

## Known Local Limitations

- Signature verification needs network access to GHCR and Sigstore services.
- Metrics Server and HPA scale-out are not part of this milestone.
- EKS, Argo CD and Terraform admission workflows are postponed.
