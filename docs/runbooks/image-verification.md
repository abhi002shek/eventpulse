# Image Verification Runbook

EventPulse publishes production images to GitHub Container Registry:

```text
ghcr.io/abhi002shek/eventpulse
```

Images should be consumed by immutable digest, not by mutable tags.

## Authenticate To GHCR

Public packages may be pullable without authentication. If authentication is required:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
```

Use a token with the minimum package-read access needed for the operation. Do not paste tokens into shell history.

## Pull By Digest

Use the digest reference from the publishing workflow summary:

```bash
docker pull ghcr.io/abhi002shek/eventpulse@sha256:<digest>
```

Digest pinning is stronger than tag pinning because a digest identifies the exact image manifest. A tag can be moved to another digest later.

## Inspect The Image

Confirm the configured runtime user:

```bash
docker image inspect ghcr.io/abhi002shek/eventpulse@sha256:<digest> \
  --format '{{ .Config.User }}'
```

Expected result:

```text
10001:10001
```

Check selected files are absent:

```bash
docker run --rm --entrypoint sh ghcr.io/abhi002shek/eventpulse@sha256:<digest> -c '
  for path in /app/.env /app/.git /app/.venv /app/tests /app/coverage.xml; do
    test ! -e "$path"
  done
'
```

## Download The SBOM

The publishing workflow uploads `eventpulse-sbom.spdx.json` as a GitHub Actions artifact named `eventpulse-sbom-spdx-json`.

From the workflow run page, open **Artifacts** and download the SBOM. With GitHub CLI:

```bash
gh run download RUN_ID --name eventpulse-sbom-spdx-json
python -m json.tool eventpulse-sbom.spdx.json >/dev/null
```

The SBOM uses SPDX JSON because SPDX is widely supported by security and compliance tooling and is readable as structured JSON.

## Verify GitHub Provenance

Where GitHub CLI attestation support is available:

```bash
gh attestation verify \
  oci://ghcr.io/abhi002shek/eventpulse@sha256:<digest> \
  --owner abhi002shek
```

The provenance subject must be the exact pushed digest, not only a tag.

## Verify The Cosign Signature

EventPulse uses Cosign keyless signing with GitHub Actions OIDC. No long-lived private signing key is used.

Expected OIDC issuer:

```text
https://token.actions.githubusercontent.com
```

Expected certificate identity pattern:

```text
^https://github\.com/abhi002shek/eventpulse/\.github/workflows/publish-image\.yml@refs/(heads/main|tags/.+)$
```

Verify the exact digest:

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/abhi002shek/eventpulse/\.github/workflows/publish-image\.yml@refs/(heads/main|tags/.+)$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/abhi002shek/eventpulse@sha256:<digest>
```

## Trivy Failure Behavior

The publishing workflow scans the locally built image before pushing to GHCR.

The workflow blocks HIGH and CRITICAL vulnerabilities while ignoring unfixed findings for the initial policy. If Trivy fails, the push, SBOM, provenance, signing and verification steps do not run.

Do not weaken the Trivy policy automatically. Review any finding before deciding whether to fix the image or document a narrow exception.

## Remove An Accidentally Published Package Version

Use GitHub's package UI:

1. Open the repository or account package list.
2. Select `eventpulse`.
3. Open the package version.
4. Delete only the incorrect version or tag.

Deleting a Git tag does not automatically delete a registry image or package version. Registry cleanup is a separate operation.
