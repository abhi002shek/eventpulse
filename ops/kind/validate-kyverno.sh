#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
POLICY_DIR="${ROOT_DIR}/policies/kyverno"
SIGNED_FIXTURE="${POLICY_DIR}/tests/resources/valid-eventpulse-deployment.yaml"
UNSIGNED_FIXTURE="${POLICY_DIR}/tests/resources/invalid-unsigned-eventpulse-image.yaml"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

wait_for_policy_reports() {
  for _ in {1..30}; do
    local report_count
    report_count="$(kubectl -n "${NAMESPACE}" get policyreports.wgpolicyk8s.io --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${report_count}" -gt 0 ]]; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for Kyverno PolicyReports in namespace '${NAMESPACE}'." >&2
  return 1
}

wait_for_policy_violations() {
  for _ in {1..30}; do
    local fail_count
    fail_count="$(
      kubectl -n "${NAMESPACE}" get policyreports.wgpolicyk8s.io \
        -o jsonpath='{range .items[*]}{.summary.fail}{"\n"}{end}' 2>/dev/null \
        | awk '{sum += $1} END {print sum + 0}'
    )"
    if [[ "${fail_count}" -gt 0 ]]; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for Audit-mode violations in PolicyReports." >&2
  return 1
}

require_tool kubectl
require_tool helm

current_context="$(kubectl config current-context)"
echo "Active Kubernetes context: ${current_context}"

if [[ "${current_context}" != "kind-eventpulse-local" ]]; then
  echo "This script is intended for the EventPulse Kind context: kind-eventpulse-local" >&2
  exit 1
fi

kubectl -n kyverno rollout status deployment/kyverno-admission-controller --timeout=180s
kubectl -n kyverno rollout status deployment/kyverno-background-controller --timeout=180s
kubectl -n kyverno rollout status deployment/kyverno-cleanup-controller --timeout=180s
kubectl -n kyverno rollout status deployment/kyverno-reports-controller --timeout=180s
kubectl get validatingwebhookconfigurations | grep kyverno

helm lint "${ROOT_DIR}/deploy/helm/eventpulse"
helm template eventpulse "${ROOT_DIR}/deploy/helm/eventpulse" --namespace "${NAMESPACE}" >/tmp/eventpulse-rendered.yaml

if command -v kubeconform >/dev/null 2>&1; then
  kubeconform -strict -summary -ignore-missing-schemas /tmp/eventpulse-rendered.yaml
else
  echo "kubeconform is not installed; rendered manifest schema validation skipped."
fi

kubectl delete -f "${POLICY_DIR}/enforce" --ignore-not-found
kubectl apply -f "${POLICY_DIR}/audit"
kubectl delete pod \
  valid-eventpulse \
  invalid-latest-image \
  invalid-root-container \
  invalid-missing-resources \
  invalid-missing-security-context \
  invalid-unapproved-registry \
  -n "${NAMESPACE}" --ignore-not-found

kubectl apply -f "${POLICY_DIR}/tests/resources/valid-eventpulse-deployment.yaml"
kubectl apply -f "${POLICY_DIR}/tests/resources/invalid-latest-image.yaml"
kubectl apply -f "${POLICY_DIR}/tests/resources/invalid-root-container.yaml"
kubectl apply -f "${POLICY_DIR}/tests/resources/invalid-missing-resources.yaml"
kubectl apply -f "${POLICY_DIR}/tests/resources/invalid-missing-security-context.yaml"
kubectl apply -f "${POLICY_DIR}/tests/resources/invalid-unapproved-registry.yaml"

wait_for_policy_reports
wait_for_policy_violations
kubectl -n "${NAMESPACE}" get policyreports.wgpolicyk8s.io -o wide

if command -v kyverno >/dev/null 2>&1; then
  kyverno test "${POLICY_DIR}/tests"
else
  echo "Kyverno CLI is not installed; offline policy tests skipped."
fi

kubectl patch clusterpolicy eventpulse-disallow-latest --type json \
  -p='[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'
kubectl patch clusterpolicy eventpulse-require-image-digest --type json \
  -p='[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'
kubectl patch clusterpolicy eventpulse-require-non-root --type json \
  -p='[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'
kubectl patch clusterpolicy eventpulse-require-security-context --type json \
  -p='[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'
kubectl patch clusterpolicy eventpulse-require-resources --type json \
  -p='[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'
kubectl patch clusterpolicy eventpulse-restrict-registries --type json \
  -p='[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'

kubectl delete pod invalid-latest-image -n "${NAMESPACE}" --ignore-not-found

if kubectl apply --dry-run=server -f "${POLICY_DIR}/tests/resources/invalid-latest-image.yaml" >/dev/null 2>&1; then
  echo "Expected latest-tag fixture to be rejected after Enforce." >&2
  exit 1
fi

kubectl apply -f "${POLICY_DIR}/enforce/verify-eventpulse-signature.yaml"

kubectl apply --dry-run=server -f "${SIGNED_FIXTURE}" >/dev/null

if kubectl apply --dry-run=server -f "${UNSIGNED_FIXTURE}" >/dev/null 2>&1; then
  echo "Expected unsigned or untrusted EventPulse image fixture to be rejected." >&2
  exit 1
fi

kubectl delete pod \
  valid-eventpulse \
  invalid-latest-image \
  invalid-root-container \
  invalid-missing-resources \
  invalid-missing-security-context \
  invalid-unapproved-registry \
  -n "${NAMESPACE}" --ignore-not-found

echo "Kyverno validation passed."
