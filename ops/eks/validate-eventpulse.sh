#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_RELEASE:-eventpulse}"
SIGNED_FIXTURE="${ROOT_DIR}/policies/kyverno/tests/resources/valid-eventpulse-deployment.yaml"
UNSIGNED_FIXTURE="${ROOT_DIR}/policies/kyverno/tests/resources/invalid-unsigned-eventpulse-image.yaml"

export AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "${PORT_FORWARD_PID:-}" ]]; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_tool aws
require_tool kubectl
require_tool python3

principal_arn="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "${principal_arn}" == arn:aws:iam::*:root ]]; then
  echo "Refusing to continue as the AWS account root principal." >&2
  exit 1
fi
echo "AWS principal: ${principal_arn}"

kubectl get nodes
not_ready_nodes="$(kubectl get nodes --no-headers | awk '$2 != "Ready" { count++ } END { print count + 0 }')"
if [[ "${not_ready_nodes}" != "0" ]]; then
  echo "All EKS worker nodes must be Ready before validation." >&2
  exit 1
fi

kubectl get csidriver secrets-store.csi.k8s.io
kubectl -n aws-secrets-manager get daemonset secrets-store-csi-driver aws-secrets-store-csi-driver-provider
kubectl -n aws-secrets-manager get pods | grep -Ei 'secrets-store|provider'
kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
kubectl -n "${NAMESPACE}" get serviceaccount eventpulse
kubectl -n "${NAMESPACE}" get secretproviderclass eventpulse-database
secret_json="$(mktemp)"
kubectl -n "${NAMESPACE}" get secret eventpulse-database -o json >"${secret_json}"
python3 - "${secret_json}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as secret_file:
    secret = json.load(secret_file)
print(f"{secret['metadata']['name']} exists with {len(secret.get('data', {}))} keys")
PY
rm -f "${secret_json}"

kubectl -n "${NAMESPACE}" wait --for=condition=complete job/"${RELEASE_NAME}"-migration --timeout=30s
kubectl -n "${NAMESPACE}" wait --for=condition=complete job/"${RELEASE_NAME}"-seed --timeout=30s
kubectl -n "${NAMESPACE}" rollout status deployment/"${RELEASE_NAME}" --timeout=180s

pods_json="$(mktemp)"
kubectl -n "${NAMESPACE}" get pods -l app.kubernetes.io/component=api -o json >"${pods_json}"
python3 - "${pods_json}" <<'PY'
import json
import sys

expected_digest = "ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224"
with open(sys.argv[1], encoding="utf-8") as pod_file:
    pods = json.load(pod_file)["items"]
if not pods:
    raise SystemExit("No EventPulse API Pods found.")
for pod in pods:
    spec = pod["spec"]
    if spec.get("automountServiceAccountToken") is not False:
        raise SystemExit(f"{pod['metadata']['name']} mounts a service account token.")
    pod_sc = spec.get("securityContext", {})
    if pod_sc.get("runAsNonRoot") is not True:
        raise SystemExit(f"{pod['metadata']['name']} is missing pod runAsNonRoot.")
    for container in spec["containers"]:
        if container["image"] != expected_digest:
            raise SystemExit(f"{pod['metadata']['name']} image is not the required digest.")
        sc = container.get("securityContext", {})
        if sc.get("runAsNonRoot") is not True or sc.get("allowPrivilegeEscalation") is not False:
            raise SystemExit(f"{pod['metadata']['name']} has an unsafe container security context.")
        if sc.get("privileged") is not False:
            raise SystemExit(f"{pod['metadata']['name']} is privileged.")
        if sc.get("capabilities", {}).get("drop") != ["ALL"]:
            raise SystemExit(f"{pod['metadata']['name']} does not drop all capabilities.")
        resources = container.get("resources", {})
        if not resources.get("requests") or not resources.get("limits"):
            raise SystemExit(f"{pod['metadata']['name']} is missing resource requests or limits.")
print("API Pods use the required digest, non-root security context, and resources.")
PY
rm -f "${pods_json}"

kubectl -n "${NAMESPACE}" get networkpolicy
kubectl -n "${NAMESPACE}" get policyreports.wgpolicyk8s.io -o wide || true

kubectl apply --dry-run=server -f "${SIGNED_FIXTURE}" >/dev/null
if kubectl apply --dry-run=server -f "${UNSIGNED_FIXTURE}" >/dev/null 2>&1; then
  echo "Expected unsigned EventPulse image fixture to be rejected." >&2
  exit 1
fi

kubectl -n "${NAMESPACE}" port-forward svc/"${RELEASE_NAME}" 18080:8000 >/tmp/eventpulse-port-forward.log 2>&1 &
PORT_FORWARD_PID="$!"
sleep 5

python3 - <<'PY'
import json
import urllib.request

for path in ("/health", "/ready", "/api/v1/events"):
    with urllib.request.urlopen(f"http://127.0.0.1:18080{path}", timeout=10) as response:
        body = response.read().decode()
        if response.status != 200:
            raise SystemExit(f"{path} returned {response.status}: {body}")
        if path == "/ready" and json.loads(body)["dependencies"]["database"] != "available":
            raise SystemExit("/ready did not report database availability.")
        print(f"{path} returned HTTP 200")
PY

echo "EventPulse EKS validation passed without printing secret values."
