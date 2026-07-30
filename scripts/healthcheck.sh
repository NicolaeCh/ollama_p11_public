#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "${BASE_DIR}/.env" ]] && source "${BASE_DIR}/.env"
HOST="${OLLAMA_API_HOST:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"
BASE_URL="http://${HOST}:${PORT}"
for path in /api/tags /api/ps; do
  echo "Checking ${BASE_URL}${path}"
  curl -fsS "${BASE_URL}${path}" | head -c 600
  echo
done
