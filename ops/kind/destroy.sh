#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${EVENTPULSE_KIND_CLUSTER:-eventpulse-local}"

if [[ -z "${CLUSTER_NAME}" || "${CLUSTER_NAME}" != "eventpulse-local" ]]; then
  echo "Refusing to delete unexpected cluster name: '${CLUSTER_NAME}'." >&2
  exit 1
fi

if ! command -v kind >/dev/null 2>&1; then
  echo "Required tool not found: kind" >&2
  exit 1
fi

if kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
  kind delete cluster --name "${CLUSTER_NAME}"
else
  echo "Kind cluster '${CLUSTER_NAME}' does not exist."
fi
