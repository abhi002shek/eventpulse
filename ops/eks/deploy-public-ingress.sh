#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_RELEASE:-eventpulse}"
DB_IDENTIFIER="${DB_IDENTIFIER:-eventpulse-dev-postgres}"
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
require_tool kubectl
require_tool helm
require_tool python3

kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deployment/eventpulse --timeout=180s
kubectl -n "${NAMESPACE}" get service eventpulse -o jsonpath='{.spec.type}{"\n"}' | grep -qx ClusterIP

rds_json="$(aws rds describe-db-instances --db-instance-identifier "${DB_IDENTIFIER}" --query 'DBInstances[0]' --output json)"
db_host="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Endpoint"]["Address"])' <<<"${rds_json}")"
db_port="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Endpoint"]["Port"])' <<<"${rds_json}")"
db_name="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("DBName") or "eventpulse")' <<<"${rds_json}")"
secret_arn="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["MasterUserSecret"]["SecretArn"])' <<<"${rds_json}")"
rds_ip="$(python3 -c 'import socket,sys; print(socket.gethostbyname(sys.argv[1]))' "${db_host}")"

public_subnet_ids="$(aws ec2 describe-subnets \
  --filters "Name=tag:kubernetes.io/role/elb,Values=1" \
  --query 'Subnets[].SubnetId' --output text)"
if [[ -z "${public_subnet_ids}" ]]; then
  echo "No public subnets with kubernetes.io/role/elb=1 found." >&2
  exit 1
fi

public_subnet_cidrs=()
while IFS= read -r cidr; do
  public_subnet_cidrs+=("${cidr}")
done <<EOF
$(aws ec2 describe-subnets \
  --subnet-ids ${public_subnet_ids} \
  --query 'Subnets[].CidrBlock' --output text | tr '\t' '\n')
EOF

helm_set_args=(
  --set-string "database.host=${db_host}"
  --set "database.port=${db_port}"
  --set-string "database.name=${db_name}"
  --set-string "database.externalSecret.secretArn=${secret_arn}"
  --set-string "database.networkPolicyEgressCidrs[0]=${rds_ip}/32"
  --set ingress.enabled=true
)

for index in "${!public_subnet_cidrs[@]}"; do
  helm_set_args+=(--set-string "networkPolicy.apiIngressCidrs[${index}]=${public_subnet_cidrs[${index}]}")
done

helm lint "${CHART_DIR}" --values "${VALUES_FILE}" "${helm_set_args[@]}"
helm template "${RELEASE_NAME}" "${CHART_DIR}" --namespace "${NAMESPACE}" --values "${VALUES_FILE}" "${helm_set_args[@]}" >/tmp/eventpulse-public-ingress.yaml

helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  "${helm_set_args[@]}" \
  --wait \
  --timeout 15m

for _ in {1..90}; do
  alb_dns="$(kubectl -n "${NAMESPACE}" get ingress eventpulse -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [[ -n "${alb_dns}" ]]; then
    break
  fi
  sleep 10
done

if [[ -z "${alb_dns:-}" ]]; then
  echo "Timed out waiting for ALB DNS assignment." >&2
  kubectl -n "${NAMESPACE}" describe ingress eventpulse >&2 || true
  exit 1
fi

lb_arn="$(aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='${alb_dns}'].LoadBalancerArn | [0]" --output text)"
if [[ -z "${lb_arn}" || "${lb_arn}" == "None" ]]; then
  echo "Could not resolve ALB ARN for ${alb_dns}." >&2
  exit 1
fi

for _ in {1..60}; do
  unhealthy="$(
    aws elbv2 describe-target-groups --load-balancer-arn "${lb_arn}" --query 'TargetGroups[].TargetGroupArn' --output text \
      | xargs -n1 aws elbv2 describe-target-health --target-group-arn \
      --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].Target.Id' --output text 2>/dev/null \
      | wc -w | tr -d ' '
  )"
  if [[ "${unhealthy}" == "0" ]]; then
    break
  fi
  sleep 10
done

echo "EventPulse public ALB DNS: ${alb_dns}"
