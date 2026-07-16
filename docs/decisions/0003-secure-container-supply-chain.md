# 0003 Secure Container Supply Chain

## Context

EventPulse already builds and validates a production-style container image in CI. The next portfolio step is to publish a verified image with evidence that consumers can inspect: vulnerability scanning, SBOM, provenance, digest-based references and keyless signatures.

## Decision

Publish EventPulse images to GitHub Container Registry at:

```text
ghcr.io/abhi002shek/eventpulse
```

The publishing workflow runs only for published releases and explicit manual dispatch. It builds the image once, scans it before publishing, pushes only approved images, captures the immutable digest, generates an SPDX JSON SBOM, creates GitHub build provenance, signs the exact digest with Cosign keyless signing and verifies that signature.

Images are always tagged with `sha-${GITHUB_SHA}`. Release runs also publish the release tag. Manual dispatch may publish a version tag only when it matches `vMAJOR.MINOR.PATCH`. The workflow does not publish `latest`.

## Alternatives Considered

- Docker Hub: familiar, but less integrated with GitHub repository permissions and attestations.
- AWS ECR: appropriate later when the AWS infrastructure phase exists.
- Google Artifact Registry: appropriate later when the GCP analytics platform exists.
- Long-lived Cosign signing keys: avoided because key management would add risk and operational overhead for this phase.
- Kubernetes admission enforcement now: postponed until a Kubernetes phase introduces Kyverno or a similar policy controller.

## Security Implications

GHCR is selected for the portfolio stage because it integrates with GitHub Actions and supports package publishing with `GITHUB_TOKEN`. No personal access token is required.

Digest references are preferred over tags because a digest identifies the exact pushed manifest. Tags are convenient labels but can move.

Trivy must pass before publishing. The initial policy blocks HIGH and CRITICAL OS and application dependency vulnerabilities while ignoring unfixed findings.

The SBOM uses SPDX JSON. SPDX is a widely supported standard and JSON is straightforward for automated validation and artifact handling.

GitHub provenance and Cosign signatures serve related but distinct verification purposes. Provenance records build identity and subject digest through GitHub's attestation flow. Cosign keyless signing signs the exact digest using a GitHub Actions OIDC identity without long-lived signing keys.

## Operational Implications

Consumers should pull and verify images by digest. The publishing workflow summary records the digest, SBOM artifact name, runtime user and verification commands.

If Trivy fails, the image is not pushed and no signing or attestation is created. The finding should be fixed or reviewed before another publish attempt.

Deleting a Git tag does not remove a GHCR package version. Registry cleanup must be performed separately.

## Cost Implications

GHCR storage may incur package storage usage over time. SBOM artifacts are retained for 30 days to keep workflow storage bounded.

The workflow uses GitHub-hosted runners rather than the EC2 SonarQube runner, so it does not add load to the self-hosted analysis host.

## Limitations

This phase does not publish to AWS ECR, Google Artifact Registry or Docker Hub.

The workflow does not enforce Kubernetes admission policies. That is postponed until Kyverno is introduced in a later Kubernetes phase.

The SBOM is uploaded as a workflow artifact and generated from the pushed digest. Registry-native SBOM attachment can be revisited when the selected registry workflow needs it.

## Consequences

EventPulse gains a secure image publishing path with scan-before-push behavior, digest-based references, SBOM evidence, GitHub provenance and keyless Cosign signatures.

Future infrastructure phases can reuse the same verification model when deploying images to Kubernetes or publishing to cloud-specific registries.
