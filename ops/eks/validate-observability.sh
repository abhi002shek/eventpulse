#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
EVENTPULSE_NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"
CLOUDWATCH_NAMESPACE="${CLOUDWATCH_NAMESPACE:-amazon-cloudwatch}"
PROM_RELEASE="${PROM_RELEASE:-eventpulse-observability}"
FLUENT_BIT_RELEASE="${FLUENT_BIT_RELEASE:-aws-for-fluent-bit}"

export AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

cleanup() {
  if [[ -n "${prom_port_forward_pid:-}" ]]; then
    kill "${prom_port_forward_pid}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

require_tool aws
require_tool curl
require_tool helm
require_tool kubectl
require_tool terraform

eval "$(aws configure export-credentials --profile "${AWS_PROFILE}" --format env)"
export AWS_REGION AWS_DEFAULT_REGION

principal_arn="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "${principal_arn}" == *":root" ]]; then
  echo "Refusing to continue with the AWS account root principal." >&2
  exit 1
fi

cluster_status="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.status' --output text)"
test "${cluster_status}" = "ACTIVE"

kubectl -n "${EVENTPULSE_NAMESPACE}" get servicemonitor eventpulse >/dev/null
kubectl -n "${EVENTPULSE_NAMESPACE}" get prometheusrule eventpulse >/dev/null
kubectl -n "${EVENTPULSE_NAMESPACE}" rollout status deployment/eventpulse --timeout=180s
kubectl -n "${MONITORING_NAMESPACE}" get pods
kubectl -n "${CLOUDWATCH_NAMESPACE}" get pods

grafana_service_type="$(kubectl -n "${MONITORING_NAMESPACE}" get service "${PROM_RELEASE}"-grafana -o jsonpath='{.spec.type}')"
prometheus_service="$(
  kubectl -n "${MONITORING_NAMESPACE}" get service \
    -l app=kube-prometheus-stack-prometheus \
    -o jsonpath='{.items[0].metadata.name}'
)"
alertmanager_service="$(
  kubectl -n "${MONITORING_NAMESPACE}" get service \
    -l app=kube-prometheus-stack-alertmanager \
    -o jsonpath='{.items[0].metadata.name}'
)"
prometheus_service_type="$(kubectl -n "${MONITORING_NAMESPACE}" get service "${prometheus_service}" -o jsonpath='{.spec.type}')"
alertmanager_service_type="$(kubectl -n "${MONITORING_NAMESPACE}" get service "${alertmanager_service}" -o jsonpath='{.spec.type}')"
test "${grafana_service_type}" = "ClusterIP"
test "${prometheus_service_type}" = "ClusterIP"
test "${alertmanager_service_type}" = "ClusterIP"

kubectl -n "${MONITORING_NAMESPACE}" port-forward service/"${prometheus_service}" 19090:9090 >/tmp/eventpulse-prometheus-port-forward.log 2>&1 &
prom_port_forward_pid="$!"
sleep 5

curl -fsS "http://127.0.0.1:19090/-/ready" >/dev/null
curl -fsS --get "http://127.0.0.1:19090/api/v1/query" --data-urlencode 'query=up{namespace="eventpulse"}' >/tmp/eventpulse-prometheus-up.json
grep -q '"status":"success"' /tmp/eventpulse-prometheus-up.json
curl -fsS "http://127.0.0.1:19090/api/v1/targets?state=active" >/tmp/eventpulse-prometheus-targets.json
python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("/tmp/eventpulse-prometheus-targets.json").read_text())
targets = [
    target
    for target in payload["data"]["activeTargets"]
    if target.get("labels", {}).get("namespace") == "eventpulse"
]
if not targets:
    raise SystemExit("No active EventPulse Prometheus targets found.")

down_targets = [target for target in targets if target.get("health") != "up"]
if down_targets:
    for target in down_targets:
        labels = target.get("labels", {})
        print(
            "EventPulse target is not healthy: "
            f"job={labels.get('job')} health={target.get('health')} "
            f"error={target.get('lastError')}"
        )
    raise SystemExit(1)
PY
curl -fsS --get "http://127.0.0.1:19090/api/v1/query" --data-urlencode 'query=eventpulse_http_requests_total' >/tmp/eventpulse-prometheus-app-metrics.json
grep -q '"status":"success"' /tmp/eventpulse-prometheus-app-metrics.json
curl -fsS --get "http://127.0.0.1:19090/api/v1/rules" --data-urlencode 'type=alert' >/tmp/eventpulse-prometheus-rules.json
grep -q 'EventPulseDeploymentUnavailable' /tmp/eventpulse-prometheus-rules.json

alb_dns="$(kubectl -n "${EVENTPULSE_NAMESPACE}" get ingress eventpulse -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
curl -fsS "http://${alb_dns}/health" >/dev/null
curl -fsS "http://${alb_dns}/ready" >/dev/null
curl -fsS "http://${alb_dns}/api/v1/events" >/dev/null

log_group_name="$(terraform -chdir="infrastructure/terraform/environments/dev/observability" output -raw eventpulse_log_group_name 2>/dev/null)"
aws logs describe-log-groups --log-group-name-prefix "${log_group_name}" --query 'logGroups[].logGroupName' --output text | grep -qx "${log_group_name}"
aws logs describe-log-streams --log-group-name "${log_group_name}" --order-by LastEventTime --descending --max-items 1 >/dev/null

echo "Observability validation passed."
echo "ALB DNS: ${alb_dns}"
echo "CloudWatch log group: ${log_group_name}"
