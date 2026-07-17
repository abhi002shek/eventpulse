#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_RELEASE:-eventpulse}"

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

helm uninstall "${RELEASE_NAME}" --namespace "${NAMESPACE}" --ignore-not-found
kubectl -n "${NAMESPACE}" delete job "${RELEASE_NAME}-migration" "${RELEASE_NAME}-seed" --ignore-not-found
kubectl -n "${NAMESPACE}" delete secret eventpulse-database --ignore-not-found

cat <<'MSG'
EventPulse workload resources were removed.

Still present and potentially billable:
- EKS control plane
- EKS managed nodes
- NAT gateway
- RDS PostgreSQL
- Secrets Manager secret
- EKS Pod Identity association
- optional Kyverno and Secrets Store CSI platform components

This script does not delete AWS infrastructure, Terraform state, RDS secrets, or Pod Identity associations.
MSG
