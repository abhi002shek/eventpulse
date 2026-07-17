#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
ADDON_NAME="aws-secrets-store-csi-driver-provider"
ADDON_VERSION="v3.1.1-eksbuild.2"
CSI_DRIVER_CHART_VERSION="1.6.0"
CSI_DRIVER_RELEASE="secrets-store-csi-driver"
CSI_DRIVER_NAMESPACE="kube-system"

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
cluster_version="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.version' --output text)"
if [[ "${cluster_status}" != "ACTIVE" ]]; then
  echo "EKS cluster '${CLUSTER_NAME}' is not ACTIVE: ${cluster_status}" >&2
  exit 1
fi
echo "EKS cluster ${CLUSTER_NAME} is ACTIVE on Kubernetes ${cluster_version}."

current_context="$(kubectl config current-context)"
echo "Active Kubernetes context: ${current_context}"
kubectl get namespace kube-system >/dev/null

compatible_version="$(
  aws eks describe-addon-versions \
    --kubernetes-version "${cluster_version}" \
    --query "addons[?addonName=='${ADDON_NAME}'].addonVersions[].addonVersion | [?@=='${ADDON_VERSION}'] | [0]" \
    --output text
)"
if [[ "${compatible_version}" != "${ADDON_VERSION}" ]]; then
  echo "Add-on ${ADDON_NAME} ${ADDON_VERSION} is not compatible with Kubernetes ${cluster_version} in ${AWS_REGION}." >&2
  exit 1
fi

if aws eks describe-addon --cluster-name "${CLUSTER_NAME}" --addon-name "${ADDON_NAME}" >/dev/null 2>&1; then
  installed_version="$(aws eks describe-addon --cluster-name "${CLUSTER_NAME}" --addon-name "${ADDON_NAME}" --query 'addon.addonVersion' --output text)"
  if [[ "${installed_version}" != "${ADDON_VERSION}" ]]; then
    echo "Updating ${ADDON_NAME} from ${installed_version} to ${ADDON_VERSION}."
    aws eks update-addon \
      --cluster-name "${CLUSTER_NAME}" \
      --addon-name "${ADDON_NAME}" \
      --addon-version "${ADDON_VERSION}" \
      --resolve-conflicts OVERWRITE >/dev/null
  else
    echo "${ADDON_NAME} ${ADDON_VERSION} is already installed."
  fi
else
  echo "Creating EKS add-on ${ADDON_NAME} ${ADDON_VERSION}."
  aws eks create-addon \
    --cluster-name "${CLUSTER_NAME}" \
    --addon-name "${ADDON_NAME}" \
    --addon-version "${ADDON_VERSION}" \
    --resolve-conflicts OVERWRITE >/dev/null
fi

for _ in {1..60}; do
  addon_status="$(aws eks describe-addon --cluster-name "${CLUSTER_NAME}" --addon-name "${ADDON_NAME}" --query 'addon.status' --output text)"
  if [[ "${addon_status}" == "ACTIVE" ]]; then
    break
  fi
  if [[ "${addon_status}" == "DEGRADED" || "${addon_status}" == "CREATE_FAILED" || "${addon_status}" == "UPDATE_FAILED" ]]; then
    echo "Add-on ${ADDON_NAME} reached ${addon_status}." >&2
    aws eks describe-addon --cluster-name "${CLUSTER_NAME}" --addon-name "${ADDON_NAME}" --query 'addon.health.issues' --output json >&2
    exit 1
  fi
  sleep 10
done

addon_status="$(aws eks describe-addon --cluster-name "${CLUSTER_NAME}" --addon-name "${ADDON_NAME}" --query 'addon.status' --output text)"
if [[ "${addon_status}" != "ACTIVE" ]]; then
  echo "Timed out waiting for ${ADDON_NAME} to become ACTIVE. Last status: ${addon_status}" >&2
  exit 1
fi
echo "${ADDON_NAME} is ACTIVE."

if kubectl get csidriver secrets-store.csi.k8s.io >/dev/null 2>&1; then
  echo "CSIDriver/secrets-store.csi.k8s.io already exists; no fallback driver install needed."
else
  echo "EKS add-on did not create CSIDriver/secrets-store.csi.k8s.io; installing official CSI driver chart ${CSI_DRIVER_CHART_VERSION}."
  helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts >/dev/null
  helm repo update secrets-store-csi-driver >/dev/null
  helm upgrade --install "${CSI_DRIVER_RELEASE}" secrets-store-csi-driver/secrets-store-csi-driver \
    --namespace "${CSI_DRIVER_NAMESPACE}" \
    --version "${CSI_DRIVER_CHART_VERSION}" \
    --set syncSecret.enabled=true \
    --set enableSecretRotation=true \
    --wait \
    --timeout 5m
fi

kubectl get csidriver secrets-store.csi.k8s.io
kubectl -n aws-secrets-manager get daemonset secrets-store-csi-driver aws-secrets-store-csi-driver-provider
kubectl -n aws-secrets-manager rollout status daemonset/secrets-store-csi-driver --timeout=180s
kubectl -n aws-secrets-manager rollout status daemonset/aws-secrets-store-csi-driver-provider --timeout=180s
kubectl -n aws-secrets-manager get pods | grep -Ei 'secrets-store|provider' || {
  echo "Could not find Secrets Store CSI/AWS provider Pods in aws-secrets-manager." >&2
  exit 1
}

echo "Secrets Store CSI integration is installed. Secret values were not read or printed."
