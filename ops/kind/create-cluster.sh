#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLUSTER_NAME="${EVENTPULSE_KIND_CLUSTER:-eventpulse-local}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"

require_tool() {
  local tool="$1"
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Required tool not found: ${tool}" >&2
    exit 1
  fi
}

require_tool kind
require_tool kubectl
require_tool docker

if kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
  echo "Kind cluster '${CLUSTER_NAME}' already exists."
else
  echo "Creating Kind cluster '${CLUSTER_NAME}' from ${SCRIPT_DIR}/cluster.yaml."
  kind create cluster --name "${CLUSTER_NAME}" --config "${SCRIPT_DIR}/cluster.yaml"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"
echo "Current Kubernetes context: $(kubectl config current-context)"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "${NAMESPACE}" \
  kubernetes.io/metadata.name="${NAMESPACE}" \
  --overwrite

cat <<EOF
Kind cluster '${CLUSTER_NAME}' is ready.
Namespace '${NAMESPACE}' exists.

Metrics Server is not installed by this script. The HPA resource will be
created, but CPU-based scaling cannot be validated until metrics-server is
installed from a pinned trusted source in a later task.
EOF
