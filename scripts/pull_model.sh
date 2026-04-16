#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <model-name>"
  exit 1
fi

MODEL="$1"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

HOST_BIND="${OLLAMA_HOST_BIND:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"

curl -fsS "http://${HOST_BIND}:${PORT}/api/pull" \
  -H 'Content-Type: application/json' \
  -d "{\"model\": \"${MODEL}\"}" 
