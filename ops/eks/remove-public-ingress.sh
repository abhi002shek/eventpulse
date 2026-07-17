#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_RELEASE:-eventpulse}"
REMOVE_CONTROLLER="${REMOVE_CONTROLLER:-false}"

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

alb_dns="$(kubectl -n "${NAMESPACE}" get ingress "${RELEASE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
kubectl -n "${NAMESPACE}" delete ingress "${RELEASE_NAME}" --ignore-not-found

if [[ -n "${alb_dns}" ]]; then
  echo "Waiting for ALB ${alb_dns} to be deleted. ALB charges continue until deletion completes."
  for _ in {1..90}; do
    remaining="$(aws elbv2 describe-load-balancers --query "length(LoadBalancers[?DNSName=='${alb_dns}'])" --output text)"
    if [[ "${remaining}" == "0" ]]; then
      echo "ALB deleted."
      break
    fi
    sleep 10
  done
fi

if [[ "${REMOVE_CONTROLLER}" == "true" ]]; then
  echo "Removing AWS Load Balancer Controller Helm release only. IAM resources remain Terraform-managed."
  helm uninstall aws-load-balancer-controller --namespace kube-system --ignore-not-found
else
  echo "Controller retained. Set REMOVE_CONTROLLER=true to remove the controller Helm release."
fi
