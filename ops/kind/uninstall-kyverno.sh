#!/usr/bin/env bash
set -euo pipefail

KYVERNO_NAMESPACE="${KYVERNO_NAMESPACE:-kyverno}"
KYVERNO_RELEASE="${KYVERNO_RELEASE:-kyverno}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

require_tool kubectl
require_tool helm

current_context="$(kubectl config current-context)"
echo "Active Kubernetes context: ${current_context}"

if [[ "${current_context}" != "kind-eventpulse-local" ]]; then
  echo "This script is intended for the EventPulse Kind context: kind-eventpulse-local" >&2
  exit 1
fi

echo "Removing EventPulse Kyverno policies."
kubectl delete -f policies/kyverno/enforce --ignore-not-found
kubectl delete -f policies/kyverno/audit --ignore-not-found

echo "Uninstalling Kyverno release '${KYVERNO_RELEASE}' from namespace '${KYVERNO_NAMESPACE}'."
helm uninstall "${KYVERNO_RELEASE}" --namespace "${KYVERNO_NAMESPACE}" --ignore-not-found

cat <<'MSG'
Kyverno release removal requested.

Helm removes the release resources, but Kubernetes may keep CRDs unless they
are removed separately. Be careful: deleting Kyverno CRDs also deletes policy
and report custom resources in the cluster.
MSG
