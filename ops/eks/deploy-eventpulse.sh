#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_PROFILE="${AWS_PROFILE:-eventpulse-user}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"
CLUSTER_NAME="${CLUSTER_NAME:-eventpulse-dev}"
NAMESPACE="${EVENTPULSE_NAMESPACE:-eventpulse}"
RELEASE_NAME="${EVENTPULSE_RELEASE:-eventpulse}"
NODEGROUP_NAME="${NODEGROUP_NAME:-eventpulse-dev-general}"
DB_IDENTIFIER="${DB_IDENTIFIER:-eventpulse-dev-postgres}"
VALUES_FILE="${ROOT_DIR}/deploy/helm/eventpulse/values-aws-dev.yaml"
CHART_DIR="${ROOT_DIR}/deploy/helm/eventpulse"
SYNC_POD_NAME="${RELEASE_NAME}-secret-sync"
APP_IMAGE="ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224"

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

principal_arn="$(aws sts get-caller-identity --query Arn --output text)"
if [[ "${principal_arn}" == arn:aws:iam::*:root ]]; then
  echo "Refusing to continue as the AWS account root principal." >&2
  exit 1
fi
echo "AWS principal: ${principal_arn}"

cluster_status="$(aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.status' --output text)"
nodegroup_status="$(aws eks describe-nodegroup --cluster-name "${CLUSTER_NAME}" --nodegroup-name "${NODEGROUP_NAME}" --query 'nodegroup.status' --output text)"
if [[ "${cluster_status}" != "ACTIVE" || "${nodegroup_status}" != "ACTIVE" ]]; then
  echo "Cluster/node group must both be ACTIVE. Cluster=${cluster_status}, nodegroup=${nodegroup_status}" >&2
  exit 1
fi

rds_json="$(aws rds describe-db-instances --db-instance-identifier "${DB_IDENTIFIER}" --query 'DBInstances[0]' --output json)"
db_status="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["DBInstanceStatus"])' <<<"${rds_json}")"
db_public="$(python3 -c 'import json,sys; print(str(json.load(sys.stdin)["PubliclyAccessible"]).lower())' <<<"${rds_json}")"
db_host="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Endpoint"]["Address"])' <<<"${rds_json}")"
db_port="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Endpoint"]["Port"])' <<<"${rds_json}")"
db_name="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("DBName") or "eventpulse")' <<<"${rds_json}")"
secret_arn="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["MasterUserSecret"]["SecretArn"])' <<<"${rds_json}")"

if [[ "${db_status}" != "available" || "${db_public}" != "false" ]]; then
  echo "RDS must be available and private. Status=${db_status}, publiclyAccessible=${db_public}" >&2
  exit 1
fi

association_count="$(
  aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" \
    --query "length(associations[?namespace=='${NAMESPACE}' && serviceAccount=='eventpulse'])" \
    --output text
)"
if [[ "${association_count}" != "1" ]]; then
  echo "Expected exactly one Pod Identity association for ${NAMESPACE}/eventpulse; found ${association_count}." >&2
  exit 1
fi

rds_ip="$(python3 -c 'import socket,sys; print(socket.gethostbyname(sys.argv[1]))' "${db_host}")"
echo "Deploying private EventPulse release '${RELEASE_NAME}' to namespace '${NAMESPACE}'."
echo "Using RDS host ${db_host}:${db_port}, database ${db_name}; secret ARN is passed to Helm but secret values are not read."

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm_args=(
  --namespace "${NAMESPACE}"
  --values "${VALUES_FILE}"
  --set-string "database.host=${db_host}"
  --set "database.port=${db_port}"
  --set-string "database.name=${db_name}"
  --set-string "database.externalSecret.secretArn=${secret_arn}"
  --set-string "database.networkPolicyEgressCidrs[0]=${rds_ip}/32"
)

bootstrap_manifest="$(mktemp)"
helm template "${RELEASE_NAME}" "${CHART_DIR}" \
  "${helm_args[@]}" \
  --show-only templates/serviceaccount.yaml \
  --show-only templates/secretproviderclass.yaml >"${bootstrap_manifest}"
kubectl -n "${NAMESPACE}" apply -f "${bootstrap_manifest}"
rm -f "${bootstrap_manifest}"
kubectl -n "${NAMESPACE}" get serviceaccount eventpulse >/dev/null
kubectl -n "${NAMESPACE}" get secretproviderclass eventpulse-database >/dev/null
kubectl -n "${NAMESPACE}" label serviceaccount eventpulse app.kubernetes.io/managed-by=Helm --overwrite
kubectl -n "${NAMESPACE}" annotate serviceaccount eventpulse \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" \
  --overwrite
kubectl -n "${NAMESPACE}" label secretproviderclass eventpulse-database app.kubernetes.io/managed-by=Helm --overwrite
kubectl -n "${NAMESPACE}" annotate secretproviderclass eventpulse-database \
  meta.helm.sh/release-name="${RELEASE_NAME}" \
  meta.helm.sh/release-namespace="${NAMESPACE}" \
  --overwrite

kubectl -n "${NAMESPACE}" delete pod "${SYNC_POD_NAME}" --ignore-not-found
kubectl -n "${NAMESPACE}" run "${SYNC_POD_NAME}" \
  --image="${APP_IMAGE}" \
  --restart=Never \
  --overrides='
{
  "apiVersion": "v1",
  "spec": {
    "automountServiceAccountToken": false,
    "serviceAccountName": "eventpulse",
    "securityContext": {
      "runAsNonRoot": true,
      "runAsUser": 10001,
      "runAsGroup": 10001,
      "fsGroup": 10001,
      "seccompProfile": {
        "type": "RuntimeDefault"
      }
    },
    "containers": [
      {
        "name": "secret-sync",
        "image": "ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224",
        "command": ["python", "-c", "import time; time.sleep(600)"],
        "securityContext": {
          "allowPrivilegeEscalation": false,
          "privileged": false,
          "readOnlyRootFilesystem": true,
          "runAsNonRoot": true,
          "runAsUser": 10001,
          "runAsGroup": 10001,
          "capabilities": {
            "drop": ["ALL"]
          }
        },
        "resources": {
          "requests": {
            "cpu": "25m",
            "memory": "64Mi"
          },
          "limits": {
            "cpu": "100m",
            "memory": "128Mi"
          }
        },
        "volumeMounts": [
          {
            "name": "external-database-secret",
            "mountPath": "/mnt/secrets-store",
            "readOnly": true
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "external-database-secret",
        "csi": {
          "driver": "secrets-store.csi.k8s.io",
          "readOnly": true,
          "volumeAttributes": {
            "secretProviderClass": "eventpulse-database"
          }
        }
      }
    ]
  }
}
'

for _ in {1..60}; do
  if kubectl -n "${NAMESPACE}" get secret eventpulse-database >/dev/null 2>&1; then
    echo "Synchronized Kubernetes Secret eventpulse-database exists. Values were not printed."
    break
  fi
  sleep 5
done

if ! kubectl -n "${NAMESPACE}" get secret eventpulse-database >/dev/null 2>&1; then
  echo "Timed out waiting for synchronized Kubernetes Secret eventpulse-database." >&2
  kubectl -n "${NAMESPACE}" describe pod "${SYNC_POD_NAME}" >&2 || true
  exit 1
fi

helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
  "${helm_args[@]}" \
  --wait \
  --timeout 15m

kubectl -n "${NAMESPACE}" wait --for=condition=complete job/"${RELEASE_NAME}"-migration --timeout=600s
kubectl -n "${NAMESPACE}" wait --for=condition=complete job/"${RELEASE_NAME}"-seed --timeout=300s
kubectl -n "${NAMESPACE}" rollout status deployment/"${RELEASE_NAME}" --timeout=300s
kubectl -n "${NAMESPACE}" delete pod "${SYNC_POD_NAME}" --ignore-not-found

echo "EventPulse deployment completed. Database credentials were not printed."
