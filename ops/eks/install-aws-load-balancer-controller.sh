#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
NODEGROUP_NAME="${NODEGROUP_NAME:-eventpulse-dev-general}"
CONTROLLER_NAMESPACE="kube-system"
CONTROLLER_SERVICE_ACCOUNT="aws-load-balancer-controller"
CONTROLLER_RELEASE="aws-load-balancer-controller"
CONTROLLER_CHART_VERSION="3.4.2"
CONTROLLER_APP_VERSION="v3.4.2"

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
require_tool jq

principal_arn="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "${principal_arn}" == arn:aws:iam::*:root ]]; then
  echo "Refusing to continue as AWS account root." >&2
  exit 1
fi
echo "AWS principal: ${principal_arn}"

cluster_json="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --output json)"
cluster_status="$(jq -r '.cluster.status' <<<"${cluster_json}")"
vpc_id="$(jq -r '.cluster.resourcesVpcConfig.vpcId' <<<"${cluster_json}")"
if [[ "${cluster_status}" != "ACTIVE" ]]; then
  echo "EKS cluster ${CLUSTER_NAME} is not ACTIVE: ${cluster_status}" >&2
  exit 1
fi

nodegroup_status="$(aws eks describe-nodegroup --cluster-name "${CLUSTER_NAME}" --nodegroup-name "${NODEGROUP_NAME}" --query 'nodegroup.status' --output text)"
if [[ "${nodegroup_status}" != "ACTIVE" ]]; then
  echo "Node group ${NODEGROUP_NAME} is not ACTIVE: ${nodegroup_status}" >&2
  exit 1
fi

not_ready_nodes="$(kubectl get nodes --no-headers | awk '$2 != "Ready" { count++ } END { print count + 0 }')"
if [[ "${not_ready_nodes}" != "0" ]]; then
  echo "All nodes must be Ready before installing the controller." >&2
  exit 1
fi

aws eks describe-addon --cluster-name "${CLUSTER_NAME}" --addon-name eks-pod-identity-agent \
  --query 'addon.{Status:status,Version:addonVersion,Health:health.issues}' --output json

association_count="$(
  aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" \
    --query "length(associations[?namespace=='${CONTROLLER_NAMESPACE}' && serviceAccount=='${CONTROLLER_SERVICE_ACCOUNT}'])" \
    --output text
)"
if [[ "${association_count}" != "1" ]]; then
  echo "Expected one Pod Identity association for ${CONTROLLER_NAMESPACE}/${CONTROLLER_SERVICE_ACCOUNT}; found ${association_count}." >&2
  echo "Apply infrastructure/terraform/environments/dev/platform before running this script." >&2
  exit 1
fi

kubectl -n "${CONTROLLER_NAMESPACE}" create serviceaccount "${CONTROLLER_SERVICE_ACCOUNT}" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "${CONTROLLER_NAMESPACE}" label serviceaccount "${CONTROLLER_SERVICE_ACCOUNT}" \
  app.kubernetes.io/name=aws-load-balancer-controller --overwrite

helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo update eks >/dev/null

helm upgrade --install "${CONTROLLER_RELEASE}" eks/aws-load-balancer-controller \
  --namespace "${CONTROLLER_NAMESPACE}" \
  --version "${CONTROLLER_CHART_VERSION}" \
  --set clusterName="${CLUSTER_NAME}" \
  --set region="${AWS_REGION}" \
  --set vpcId="${vpc_id}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="${CONTROLLER_SERVICE_ACCOUNT}" \
  --set image.tag="${CONTROLLER_APP_VERSION}" \
  --wait \
  --timeout 10m

kubectl -n "${CONTROLLER_NAMESPACE}" rollout status deployment/aws-load-balancer-controller --timeout=300s
kubectl get validatingwebhookconfiguration aws-load-balancer-webhook
kubectl get mutatingwebhookconfiguration aws-load-balancer-webhook

echo "AWS Load Balancer Controller ${CONTROLLER_APP_VERSION} chart ${CONTROLLER_CHART_VERSION} is installed."
