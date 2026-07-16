#!/usr/bin/env bash
set -euo pipefail

KYVERNO_NAMESPACE="${KYVERNO_NAMESPACE:-kyverno}"
KYVERNO_RELEASE="${KYVERNO_RELEASE:-kyverno}"
KYVERNO_CHART_VERSION="3.8.2"

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

helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null
helm repo update kyverno >/dev/null

helm upgrade --install "${KYVERNO_RELEASE}" kyverno/kyverno \
  --namespace "${KYVERNO_NAMESPACE}" \
  --create-namespace \
  --version "${KYVERNO_CHART_VERSION}" \
  --set admissionController.replicas=1 \
  --set backgroundController.replicas=1 \
  --set cleanupController.replicas=1 \
  --set reportsController.replicas=1 \
  --wait \
  --timeout 5m

kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-admission-controller --timeout=180s
kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-background-controller --timeout=180s
kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-cleanup-controller --timeout=180s
kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-reports-controller --timeout=180s

kubectl wait --for=condition=Established crd/clusterpolicies.kyverno.io --timeout=120s
kubectl get validatingwebhookconfigurations | grep kyverno

echo "Kyverno ${KYVERNO_CHART_VERSION} is installed in namespace '${KYVERNO_NAMESPACE}'."
