#!/usr/bin/env bash
set -euo pipefail

EVENTPULSE_NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-eventpulse}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

require_tool curl
require_tool kubectl

original_replicas="$(kubectl -n "${EVENTPULSE_NAMESPACE}" get deployment "${DEPLOYMENT_NAME}" -o jsonpath='{.spec.replicas}')"

restore_replicas() {
  kubectl -n "${EVENTPULSE_NAMESPACE}" scale deployment/"${DEPLOYMENT_NAME}" --replicas="${original_replicas}" >/dev/null 2>&1 || true
}
trap restore_replicas EXIT

alb_dns="$(kubectl -n "${EVENTPULSE_NAMESPACE}" get ingress "${DEPLOYMENT_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
if [[ -z "${alb_dns}" ]]; then
  echo "Could not find EventPulse ALB DNS." >&2
  exit 1
fi

first_pod="$(kubectl -n "${EVENTPULSE_NAMESPACE}" get pods -l app.kubernetes.io/component=api -o jsonpath='{.items[0].metadata.name}')"
echo "Deleting one EventPulse API pod: ${first_pod}"
kubectl -n "${EVENTPULSE_NAMESPACE}" delete pod "${first_pod}" --wait=false
kubectl -n "${EVENTPULSE_NAMESPACE}" rollout status deployment/"${DEPLOYMENT_NAME}" --timeout=180s
curl -fsS "http://${alb_dns}/health" >/dev/null

echo "Temporarily scaling EventPulse API to one replica."
kubectl -n "${EVENTPULSE_NAMESPACE}" scale deployment/"${DEPLOYMENT_NAME}" --replicas=1
kubectl -n "${EVENTPULSE_NAMESPACE}" rollout status deployment/"${DEPLOYMENT_NAME}" --timeout=180s
curl -fsS "http://${alb_dns}/ready" >/dev/null

echo "Restoring EventPulse API replicas to ${original_replicas}."
kubectl -n "${EVENTPULSE_NAMESPACE}" scale deployment/"${DEPLOYMENT_NAME}" --replicas="${original_replicas}"
kubectl -n "${EVENTPULSE_NAMESPACE}" rollout status deployment/"${DEPLOYMENT_NAME}" --timeout=180s
curl -fsS "http://${alb_dns}/api/v1/events" >/dev/null

echo "Controlled resilience checks passed."
