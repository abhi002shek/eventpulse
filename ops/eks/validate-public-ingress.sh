#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_RELEASE:-eventpulse}"
DB_IDENTIFIER="${DB_IDENTIFIER:-eventpulse-dev-postgres}"

export AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool '$1' was not found." >&2
    exit 1
  fi
}

require_tool aws
require_tool kubectl
require_tool python3
require_tool curl

kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deployment/"${RELEASE_NAME}" --timeout=180s

service_type="$(kubectl -n "${NAMESPACE}" get service "${RELEASE_NAME}" -o jsonpath='{.spec.type}')"
if [[ "${service_type}" != "ClusterIP" ]]; then
  echo "Expected EventPulse Service to remain ClusterIP, got ${service_type}." >&2
  exit 1
fi

alb_dns="$(kubectl -n "${NAMESPACE}" get ingress "${RELEASE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
if [[ -z "${alb_dns}" ]]; then
  echo "Ingress does not have an ALB hostname yet." >&2
  exit 1
fi

kubectl -n "${NAMESPACE}" get ingress "${RELEASE_NAME}" -o jsonpath='{.metadata.annotations}' | grep -q 'internet-facing'
kubectl -n "${NAMESPACE}" get ingress "${RELEASE_NAME}" -o jsonpath='{.metadata.annotations}' | grep -q 'ip'

lb_json="$(aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='${alb_dns}'] | [0]" --output json)"
scheme="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Scheme"])' <<<"${lb_json}")"
lb_arn="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["LoadBalancerArn"])' <<<"${lb_json}")"
subnets="$(python3 -c 'import json,sys; print(" ".join(a["SubnetId"] for a in json.load(sys.stdin)["AvailabilityZones"]))' <<<"${lb_json}")"
if [[ "${scheme}" != "internet-facing" ]]; then
  echo "Expected internet-facing ALB, got ${scheme}." >&2
  exit 1
fi

aws ec2 describe-subnets --subnet-ids ${subnets} --query 'Subnets[].Tags[?Key==`kubernetes.io/role/elb`].Value' --output text | grep -q '1'

target_group_arns="$(aws elbv2 describe-target-groups --load-balancer-arn "${lb_arn}" --query 'TargetGroups[].TargetGroupArn' --output text)"
for target_group_arn in ${target_group_arns}; do
  target_type="$(aws elbv2 describe-target-groups --target-group-arns "${target_group_arn}" --query 'TargetGroups[0].TargetType' --output text)"
  if [[ "${target_type}" != "ip" ]]; then
    echo "Expected target type ip, got ${target_type}." >&2
    exit 1
  fi
  aws elbv2 describe-target-health --target-group-arn "${target_group_arn}" --output table
  unhealthy="$(aws elbv2 describe-target-health --target-group-arn "${target_group_arn}" --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].Target.Id' --output text | wc -w | tr -d ' ')"
  if [[ "${unhealthy}" != "0" ]]; then
    echo "One or more ALB targets are not healthy." >&2
    exit 1
  fi
done

for path in /health /ready /api/v1/events; do
  curl -fsS "http://${alb_dns}${path}" >/dev/null
  echo "http://${alb_dns}${path} returned HTTP 200"
done

if curl -fsS "http://${alb_dns}/api/v1/namespaces" >/dev/null 2>&1; then
  echo "Unexpected Kubernetes-like endpoint responded publicly." >&2
  exit 1
fi

rds_public="$(aws rds describe-db-instances --db-instance-identifier "${DB_IDENTIFIER}" --query 'DBInstances[0].PubliclyAccessible' --output text)"
if [[ "${rds_public}" != "False" ]]; then
  echo "RDS must remain private." >&2
  exit 1
fi

kubectl -n kube-system logs deployment/aws-load-balancer-controller --tail=100 | grep -Ei 'error|failed' || true
echo "Public ALB validation passed for ${alb_dns}."
