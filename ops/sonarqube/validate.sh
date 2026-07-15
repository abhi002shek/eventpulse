#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/compose.yaml"
ENV_FILE="${SCRIPT_DIR}/.env.sonar"

SONAR_IMAGE="sonarqube:26.7.0.124771-community@sha256:5a40959752dcc1e1408ff18d8ce35be30711323ed5612d3a49d65e093dc34454"
POSTGRES_IMAGE="postgres:16.14-alpine3.24@sha256:7a396fd264a2067788b6551122b50f162bf6136312c7fc9d74381cb92c648382"
PROJECT_NAME="eventpulse-sonarqube"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

compose() {
  docker compose --env-file "${ENV_FILE}" --file "${COMPOSE_FILE}" "$@"
}

echo "Checking SonarQube environment file..."
[[ -f "${ENV_FILE}" ]] || fail "${ENV_FILE} does not exist. Create it from .env.sonar.example."

if command -v stat >/dev/null 2>&1; then
  env_mode="$(stat -c '%a' "${ENV_FILE}" 2>/dev/null || stat -f '%Lp' "${ENV_FILE}")"
  case "${env_mode}" in
    600 | 400) ;;
    *) fail "${ENV_FILE} permissions are ${env_mode}; use chmod 600 ${ENV_FILE}." ;;
  esac
fi

echo "Validating Docker Compose syntax without printing secrets..."
config_file="$(mktemp)"
trap 'rm -f "${config_file}"' EXIT
compose config >"${config_file}"

echo "Checking host sysctl settings..."
[[ "$(sysctl -n vm.max_map_count)" -ge 524288 ]] || fail "vm.max_map_count must be at least 524288."
[[ "$(sysctl -n fs.file-max)" -ge 131072 ]] || fail "fs.file-max must be at least 131072."

echo "Starting SonarQube stack..."
compose up -d

wait_for_container_health() {
  local container_name="$1"
  local timeout_seconds="$2"
  local started_at
  started_at="$(date +%s)"

  while true; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_name}" 2>/dev/null || true)"
    if [[ "${status}" == "healthy" ]]; then
      echo "${container_name} is healthy."
      return 0
    fi

    if (( "$(date +%s)" - started_at > timeout_seconds )); then
      docker ps --filter "name=${container_name}" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
      fail "${container_name} did not become healthy within ${timeout_seconds} seconds."
    fi

    sleep 10
  done
}

wait_for_container_health "${PROJECT_NAME}-sonar-db-1" 180
wait_for_container_health "${PROJECT_NAME}-sonarqube-1" 900

echo "Checking port binding for SonarQube..."
sonar_ports="$(docker port "${PROJECT_NAME}-sonarqube-1" 9000/tcp)"
if [[ "${sonar_ports}" != "127.0.0.1:9000" ]]; then
  echo "Observed SonarQube port binding: ${sonar_ports}" >&2
  fail "SonarQube must bind only to 127.0.0.1:9000."
fi

echo "Checking that PostgreSQL has no published host port..."
db_ports="$(docker port "${PROJECT_NAME}-sonar-db-1" || true)"
[[ -z "${db_ports}" ]] || fail "PostgreSQL must not publish host ports."

echo "Checking image references..."
actual_sonar_image="$(docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.version" }}' "${PROJECT_NAME}-sonarqube-1")"
[[ "${actual_sonar_image}" == "26.7.0.124771-community" ]] || fail "Unexpected SonarQube version label: ${actual_sonar_image}"

compose_sonar_image="$(docker inspect --format '{{.Config.Image}}' "${PROJECT_NAME}-sonarqube-1")"
compose_db_image="$(docker inspect --format '{{.Config.Image}}' "${PROJECT_NAME}-sonar-db-1")"
[[ "${compose_sonar_image}" == "${SONAR_IMAGE}" ]] || fail "Unexpected SonarQube image reference."
[[ "${compose_db_image}" == "${POSTGRES_IMAGE}" ]] || fail "Unexpected PostgreSQL image reference."

echo "Checking named volumes..."
for volume in \
  "${PROJECT_NAME}_sonar_db_data" \
  "${PROJECT_NAME}_sonarqube_data" \
  "${PROJECT_NAME}_sonarqube_logs" \
  "${PROJECT_NAME}_sonarqube_extensions"; do
  docker volume inspect "${volume}" >/dev/null || fail "Expected named volume missing: ${volume}"
done

echo "Container status:"
compose ps

echo "Validation completed successfully. No passwords or full environment contents were printed."
