#!/usr/bin/env bash
set -euo pipefail

MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
CLOUDWATCH_NAMESPACE="${CLOUDWATCH_NAMESPACE:-amazon-cloudwatch}"
PROM_RELEASE="${PROM_RELEASE:-eventpulse-observability}"
FLUENT_BIT_RELEASE="${FLUENT_BIT_RELEASE:-aws-for-fluent-bit}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

require_tool helm
require_tool kubectl

helm uninstall "${FLUENT_BIT_RELEASE}" --namespace "${CLOUDWATCH_NAMESPACE}" || true
helm uninstall "${PROM_RELEASE}" --namespace "${MONITORING_NAMESPACE}" || true

kubectl -n "${MONITORING_NAMESPACE}" delete configmap eventpulse-overview-dashboard eventpulse-kubernetes-workload-dashboard --ignore-not-found=true

echo "Observability Helm releases removed."
echo "Terraform-managed CloudWatch log group and IAM resources were not destroyed."
echo "Run terraform destroy in the observability environment only when you intentionally want to remove those AWS resources."
