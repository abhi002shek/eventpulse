#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLUSTER_NAME="${EVENTPULSE_KIND_CLUSTER:-eventpulse-local}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_HELM_RELEASE:-eventpulse}"
CHART_DIR="${REPO_ROOT}/deploy/helm/eventpulse"

require_tool() {
  local tool="$1"
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Required tool not found: ${tool}" >&2
    exit 1
  fi
}

require_tool kubectl
require_tool helm

if [[ "$(kubectl config current-context)" != "kind-${CLUSTER_NAME}" ]]; then
  echo "Current context is '$(kubectl config current-context)', expected 'kind-${CLUSTER_NAME}'." >&2
  echo "Run ops/kind/create-cluster.sh first or switch context intentionally." >&2
  exit 1
fi

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

DB_PASSWORD="${EVENTPULSE_DB_PASSWORD:-}"
if [[ -z "${DB_PASSWORD}" ]]; then
  DB_PASSWORD="CHANGE_ME_LOCAL_ONLY_FAKE_PASSWORD"
  echo "EVENTPULSE_DB_PASSWORD is not set; using an obvious local-only fake password." >&2
fi

kubectl -n "${NAMESPACE}" create secret generic eventpulse-database \
  --from-literal=DATABASE_PASSWORD="${DB_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

helm dependency update "${CHART_DIR}"

helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --set database.secret.create=false \
  --set database.secret.name=eventpulse-database \
  --set seed.enabled=true \
  --wait \
  --wait-for-jobs \
  --timeout 10m

kubectl -n "${NAMESPACE}" rollout status "deployment/${RELEASE_NAME}" --timeout=5m

echo "EventPulse deployed to namespace '${NAMESPACE}'."
