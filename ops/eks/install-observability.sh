#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
EVENTPULSE_NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
CLOUDWATCH_NAMESPACE="${CLOUDWATCH_NAMESPACE:-amazon-cloudwatch}"
PROM_RELEASE="${PROM_RELEASE:-eventpulse-observability}"
FLUENT_BIT_RELEASE="${FLUENT_BIT_RELEASE:-aws-for-fluent-bit}"
KUBE_PROMETHEUS_STACK_CHART_VERSION="87.17.0"
KUBE_PROMETHEUS_STACK_APP_VERSION="v0.92.1"
AWS_FOR_FLUENT_BIT_CHART_VERSION="0.2.0"
AWS_FOR_FLUENT_BIT_APP_VERSION="3.2.1"
OBSERVABILITY_TF_DIR="${ROOT_DIR}/infrastructure/terraform/environments/dev/observability"
CHART_DIR="${ROOT_DIR}/deploy/helm/eventpulse"
VALUES_FILE="${CHART_DIR}/values-aws-dev.yaml"

export AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

require_tool aws
require_tool helm
require_tool kubectl
require_tool terraform
require_tool python3

eval "$(aws configure export-credentials --profile "${AWS_PROFILE}" --format env)"
export AWS_REGION AWS_DEFAULT_REGION

fluent_values_file="$(mktemp)"
cleanup() {
  rm -f "${fluent_values_file}"
}
trap cleanup EXIT

cat >"${fluent_values_file}" <<'EOF'
additionalFilters: |
  [FILTER]
      Name grep
      Match kube.*
      Regex $kubernetes['namespace_name'] ^eventpulse$
EOF

principal_arn="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "${principal_arn}" == *":root" ]]; then
  echo "Refusing to continue with the AWS account root principal." >&2
  exit 1
fi

cluster_status="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.status' --output text)"
if [[ "${cluster_status}" != "ACTIVE" ]]; then
  echo "EKS cluster ${CLUSTER_NAME} is not ACTIVE: ${cluster_status}" >&2
  exit 1
fi

kubectl config current-context
kubectl get nodes

ready_nodes="$(kubectl get nodes --no-headers | awk '$2 == "Ready" { count++ } END { print count + 0 }')"
if (( ready_nodes < 2 )); then
  echo "Expected at least two Ready nodes before installing observability; found ${ready_nodes}." >&2
  exit 1
fi

log_group_name="$(terraform -chdir="${OBSERVABILITY_TF_DIR}" output -raw eventpulse_log_group_name 2>/dev/null || true)"
if [[ -z "${log_group_name}" ]]; then
  echo "Observability Terraform outputs are unavailable." >&2
  echo "Run terraform init/plan/apply in ${OBSERVABILITY_TF_DIR} before installing Fluent Bit." >&2
  exit 1
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add aws https://aws.github.io/eks-charts >/dev/null
helm repo update prometheus-community aws >/dev/null

kubectl create namespace "${MONITORING_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace "${CLOUDWATCH_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${MONITORING_NAMESPACE}" create configmap eventpulse-overview-dashboard \
  --from-file=eventpulse-overview.json="${ROOT_DIR}/observability/grafana/eventpulse-overview.json" \
  --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -

kubectl -n "${MONITORING_NAMESPACE}" create configmap eventpulse-kubernetes-workload-dashboard \
  --from-file=kubernetes-workload.json="${ROOT_DIR}/observability/grafana/kubernetes-workload.json" \
  --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 --dry-run=client -o yaml \
  | kubectl apply -f -

helm upgrade --install "${PROM_RELEASE}" prometheus-community/kube-prometheus-stack \
  --namespace "${MONITORING_NAMESPACE}" \
  --version "${KUBE_PROMETHEUS_STACK_CHART_VERSION}" \
  --set grafana.defaultDashboardsTimezone=utc \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.label=grafana_dashboard \
  --set grafana.service.type=ClusterIP \
  --set prometheus.service.type=ClusterIP \
  --set alertmanager.service.type=ClusterIP \
  --set prometheus.prometheusSpec.retention=3d \
  --set prometheus.prometheusSpec.retentionSize=8GB \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --wait \
  --timeout 15m

helm upgrade --install "${FLUENT_BIT_RELEASE}" aws/aws-for-fluent-bit \
  --namespace "${CLOUDWATCH_NAMESPACE}" \
  --version "${AWS_FOR_FLUENT_BIT_CHART_VERSION}" \
  --values "${fluent_values_file}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-for-fluent-bit \
  --set cloudWatch.enabled=false \
  --set cloudWatchLogs.enabled=true \
  --set-string "cloudWatchLogs.region=${AWS_REGION}" \
  --set-string "cloudWatchLogs.logGroupName=${log_group_name}" \
  --set cloudWatchLogs.autoCreateGroup=false \
  --set-string cloudWatchLogs.logStreamPrefix=eventpulse- \
  --set firehose.enabled=false \
  --set kinesis.enabled=false \
  --set kinesis_streams.enabled=false \
  --set elasticsearch.enabled=false \
  --set opensearch.enabled=false \
  --set s3.enabled=false \
  --set containerSecurityContext.allowPrivilegeEscalation=false \
  --set containerSecurityContext.privileged=false \
  --set containerSecurityContext.capabilities.drop[0]=ALL \
  --wait \
  --timeout 10m

ops_helm_set_args=(
  --set monitoring.enabled=true
  --set monitoring.serviceMonitor.enabled=true
  --set monitoring.prometheusRule.enabled=true
  --set-string "monitoring.prometheusNamespace=${MONITORING_NAMESPACE}"
)

"${ROOT_DIR}/ops/eks/deploy-public-ingress.sh" "${ops_helm_set_args[@]}"

kubectl -n "${MONITORING_NAMESPACE}" rollout status deployment/"${PROM_RELEASE}"-grafana --timeout=180s
prometheus_statefulset="$(
  kubectl -n "${MONITORING_NAMESPACE}" get statefulset \
    -l app.kubernetes.io/name=prometheus \
    -o jsonpath='{.items[0].metadata.name}'
)"
alertmanager_statefulset="$(
  kubectl -n "${MONITORING_NAMESPACE}" get statefulset \
    -l app.kubernetes.io/name=alertmanager \
    -o jsonpath='{.items[0].metadata.name}'
)"
kubectl -n "${MONITORING_NAMESPACE}" rollout status statefulset/"${prometheus_statefulset}" --timeout=300s
kubectl -n "${MONITORING_NAMESPACE}" rollout status statefulset/"${alertmanager_statefulset}" --timeout=300s
kubectl -n "${CLOUDWATCH_NAMESPACE}" rollout status daemonset/"${FLUENT_BIT_RELEASE}" --timeout=180s

echo "Installed kube-prometheus-stack ${KUBE_PROMETHEUS_STACK_CHART_VERSION} (${KUBE_PROMETHEUS_STACK_APP_VERSION})."
echo "Installed aws-for-fluent-bit ${AWS_FOR_FLUENT_BIT_CHART_VERSION} (${AWS_FOR_FLUENT_BIT_APP_VERSION})."
echo "Grafana is ClusterIP-only. Use kubectl port-forward in the runbook to access it."
