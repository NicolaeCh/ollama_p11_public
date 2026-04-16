#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

HOST_BIND="${OLLAMA_HOST_BIND:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"

curl -fsS "http://${HOST_BIND}:${PORT}/api/tags"
