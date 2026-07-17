#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
KYVERNO_NAMESPACE="${KYVERNO_NAMESPACE:-kyverno}"
KYVERNO_RELEASE="${KYVERNO_RELEASE:-kyverno}"
KYVERNO_CHART_VERSION="3.8.2"
EVENTPULSE_NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
POLICY_DIR="${ROOT_DIR}/policies/kyverno"

export AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

require_tool aws
require_tool kubectl
require_tool helm

principal_arn="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "${principal_arn}" == arn:aws:iam::*:root ]]; then
  echo "Refusing to continue as the AWS account root principal." >&2
  exit 1
fi
echo "AWS principal: ${principal_arn}"

cluster_status="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.status' --output text)"
if [[ "${cluster_status}" != "ACTIVE" ]]; then
  echo "EKS cluster '${CLUSTER_NAME}' is not ACTIVE: ${cluster_status}" >&2
  exit 1
fi

current_context="$(kubectl config current-context)"
echo "Active Kubernetes context: ${current_context}"
kubectl create namespace "${EVENTPULSE_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null
helm repo update kyverno >/dev/null

helm upgrade --install "${KYVERNO_RELEASE}" kyverno/kyverno \
  --namespace "${KYVERNO_NAMESPACE}" \
  --create-namespace \
  --version "${KYVERNO_CHART_VERSION}" \
  --set admissionController.replicas=2 \
  --set backgroundController.replicas=1 \
  --set cleanupController.replicas=1 \
  --set reportsController.replicas=1 \
  --wait \
  --timeout 10m

kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-admission-controller --timeout=300s
kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-background-controller --timeout=300s
kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-cleanup-controller --timeout=300s
kubectl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-reports-controller --timeout=300s
kubectl wait --for=condition=Established crd/clusterpolicies.kyverno.io --timeout=180s
kubectl get validatingwebhookconfigurations | grep kyverno

kubectl delete -f "${POLICY_DIR}/enforce" --ignore-not-found
kubectl apply -f "${POLICY_DIR}/audit"

echo "Audit policies are installed. Waiting briefly for policy reports."
sleep 10
kubectl -n "${EVENTPULSE_NAMESPACE}" get policyreports.wgpolicyk8s.io -o wide || true

for policy in \
  eventpulse-disallow-latest \
  eventpulse-require-image-digest \
  eventpulse-require-non-root \
  eventpulse-require-security-context \
  eventpulse-require-resources \
  eventpulse-restrict-registries; do
  kubectl patch clusterpolicy "${policy}" --type json \
    -p='[{"op":"replace","path":"/spec/rules/0/validate/failureAction","value":"Enforce"}]'
done

kubectl apply -f "${POLICY_DIR}/enforce/verify-eventpulse-signature.yaml"

echo "Kyverno ${KYVERNO_CHART_VERSION} is installed. Standard EventPulse policies and signature verification are enforced."
