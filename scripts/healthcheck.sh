#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

HOST_BIND="${OLLAMA_HOST_BIND:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"
BASE_URL="http://${HOST_BIND}:${PORT}"

check() {
  local path="$1"
  echo "Checking ${BASE_URL}${path}"
  curl -fsS "${BASE_URL}${path}" | head -c 400
  echo
}

check "/api/tags"
check "/api/ps"
