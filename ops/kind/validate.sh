#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLUSTER_NAME="${EVENTPULSE_KIND_CLUSTER:-eventpulse-local}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_HELM_RELEASE:-eventpulse}"
CHART_DIR="${REPO_ROOT}/deploy/helm/eventpulse"
EXPECTED_DIGEST="sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224"

require_tool() {
  local tool="$1"
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Required tool not found: ${tool}" >&2
    exit 1
  fi
}

require_tool kubectl
require_tool helm
require_tool python3

if [[ "$(kubectl config current-context)" != "kind-${CLUSTER_NAME}" ]]; then
  echo "Current context is '$(kubectl config current-context)', expected 'kind-${CLUSTER_NAME}'." >&2
  exit 1
fi

kubectl cluster-info >/dev/null

helm lint "${CHART_DIR}"
helm template "${RELEASE_NAME}" "${CHART_DIR}" --namespace "${NAMESPACE}" >/tmp/eventpulse-rendered.yaml
helm template "${RELEASE_NAME}" "${CHART_DIR}" --namespace "${NAMESPACE}" \
  --set image.digest="" >/tmp/eventpulse-invalid.yaml 2>/tmp/eventpulse-invalid.err && {
    echo "Expected Helm schema validation to reject an empty image digest." >&2
    exit 1
  }

if command -v kubeconform >/dev/null 2>&1; then
  kubeconform -strict -summary /tmp/eventpulse-rendered.yaml
else
  echo "kubeconform is not installed; rendered manifest schema validation skipped."
fi

kubectl -n "${NAMESPACE}" get pods
kubectl -n "${NAMESPACE}" get jobs
kubectl -n "${NAMESPACE}" rollout status "deployment/${RELEASE_NAME}" --timeout=5m

if [[ -z "$(kubectl -n "${NAMESPACE}" get endpoints "${RELEASE_NAME}" -o jsonpath='{.subsets[*].addresses[*].ip}')" ]]; then
  echo "Service '${RELEASE_NAME}' has no ready endpoints." >&2
  exit 1
fi

pod_name="$(kubectl -n "${NAMESPACE}" get pod \
  -l app.kubernetes.io/name=eventpulse,app.kubernetes.io/instance="${RELEASE_NAME}",app.kubernetes.io/component=api \
  -o jsonpath='{.items[0].metadata.name}')"

image="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.spec.containers[0].image}')"
if [[ "${image}" != *"@${EXPECTED_DIGEST}" ]]; then
  echo "Unexpected API image: ${image}" >&2
  exit 1
fi

run_as_user="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.spec.containers[0].securityContext.runAsUser}')"
if [[ "${run_as_user}" == "0" || -z "${run_as_user}" ]]; then
  echo "API container is not explicitly configured with a non-root UID." >&2
  exit 1
fi

privileged="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.spec.containers[0].securityContext.privileged}')"
if [[ "${privileged}" != "false" ]]; then
  echo "API container privileged mode is not false." >&2
  exit 1
fi

automount="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.spec.automountServiceAccountToken}')"
if [[ "${automount}" != "false" ]]; then
  echo "API pod service-account token automount is not disabled." >&2
  exit 1
fi

requests_cpu="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')"
limits_memory="$(kubectl -n "${NAMESPACE}" get pod "${pod_name}" -o jsonpath='{.spec.containers[0].resources.limits.memory}')"
if [[ -z "${requests_cpu}" || -z "${limits_memory}" ]]; then
  echo "API container resources are incomplete." >&2
  exit 1
fi

kubectl -n "${NAMESPACE}" get networkpolicy "${RELEASE_NAME}-default-deny" >/dev/null
kubectl -n "${NAMESPACE}" get networkpolicy "${RELEASE_NAME}-api" >/dev/null
kubectl -n "${NAMESPACE}" get networkpolicy "${RELEASE_NAME}-jobs" >/dev/null
kubectl -n "${NAMESPACE}" get networkpolicy "${RELEASE_NAME}-postgres" >/dev/null
kubectl -n "${NAMESPACE}" get networkpolicy "${RELEASE_NAME}-tests" >/dev/null
kubectl -n "${NAMESPACE}" get hpa "${RELEASE_NAME}" >/dev/null
kubectl -n "${NAMESPACE}" get pdb "${RELEASE_NAME}" >/dev/null

kubectl -n "${NAMESPACE}" port-forward "svc/${RELEASE_NAME}" 18000:8000 >/tmp/eventpulse-port-forward.log 2>&1 &
pf_pid="$!"
trap 'kill "${pf_pid}" >/dev/null 2>&1 || true; wait "${pf_pid}" 2>/dev/null || true' EXIT

for _ in {1..30}; do
  if python3 -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:18000/health', timeout=2).read()" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

python3 -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:18000/health', timeout=5).read()"
python3 -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:18000/ready', timeout=5).read()"
python3 -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:18000/api/v1/events', timeout=5).read()"

trap 'kill "${pf_pid}" >/dev/null 2>&1 || true; wait "${pf_pid}" 2>/dev/null || true; kubectl -n "${NAMESPACE}" delete pod -l app.kubernetes.io/component=test --ignore-not-found >/dev/null 2>&1 || true' EXIT
helm test "${RELEASE_NAME}" --namespace "${NAMESPACE}" --logs
kubectl -n "${NAMESPACE}" delete pod -l app.kubernetes.io/component=test --ignore-not-found

echo "EventPulse Kind validation passed."
