#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <new-model-name> <modelfile-path>"
  exit 1
fi

MODEL_NAME="$1"
MODELFILE_PATH="$2"

if [[ ! -f "${MODELFILE_PATH}" ]]; then
  echo "Modelfile not found: ${MODELFILE_PATH}"
  exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

HOST_BIND="${OLLAMA_HOST_BIND:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"
ESCAPED_CONTENT="$(python3 - <<PY
import json, pathlib
print(json.dumps(pathlib.Path('${MODELFILE_PATH}').read_text()))
PY
)"

curl -fsS "http://${HOST_BIND}:${PORT}/api/create" \
  -H 'Content-Type: application/json' \
  -d "{\"model\": \"${MODEL_NAME}\", \"modelfile\": ${ESCAPED_CONTENT}}"
