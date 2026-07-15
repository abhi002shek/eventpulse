#!/usr/bin/env bash
set -euo pipefail

DOCKER_USER=""

usage() {
  cat <<'USAGE'
Usage: sudo ./setup-host.sh [--docker-user USERNAME]

Prepares an Ubuntu 24.04 host for the EventPulse SonarQube Community Build stack.
The optional --docker-user argument adds an existing dedicated operator user to
the docker group. Docker group membership is root-equivalent host access.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker-user)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "ERROR: --docker-user requires a username." >&2
        exit 2
      fi
      DOCKER_USER="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: run this script as root, for example: sudo $0" >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
else
  echo "ERROR: /etc/os-release is missing; cannot verify operating system." >&2
  exit 1
fi

if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "ERROR: this script is intended for Ubuntu 24.04." >&2
  echo "Detected: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

echo "Installing required packages and Docker Engine from Docker's official repository..."
install -m 0755 -d /etc/apt/keyrings
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl gnupg

if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

ARCH="$(dpkg --print-architecture)"
CODENAME="$(
  # shellcheck disable=SC1091
  . /etc/os-release
  printf '%s' "${VERSION_CODENAME}"
)"

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable
EOF

apt-get update
apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "Configuring persistent SonarQube and Elasticsearch host settings..."
cat >/etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl --system

cat >/etc/security/limits.d/99-sonarqube.conf <<'EOF'
* soft nofile 131072
* hard nofile 131072
* soft nproc 8192
* hard nproc 8192
EOF

systemctl enable --now docker

if [[ -n "${DOCKER_USER}" ]]; then
  if ! id "${DOCKER_USER}" >/dev/null 2>&1; then
    echo "ERROR: user '${DOCKER_USER}' does not exist. Create the dedicated operator user first." >&2
    exit 1
  fi
  usermod -aG docker "${DOCKER_USER}"
  echo "Added '${DOCKER_USER}' to the docker group."
  echo "WARNING: docker group membership provides root-equivalent host access."
  echo "The user must sign out and back in before group membership is active."
else
  echo "No operator user was added to the docker group."
  echo "To add one later, rerun: sudo ./setup-host.sh --docker-user USERNAME"
fi

echo "Host setup complete. This script did not create AWS credentials, open firewall ports, or register a GitHub runner."
