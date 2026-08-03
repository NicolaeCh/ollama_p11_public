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

RUNTIME="${CONTAINER_RUNTIME:-podman}"
NAME="${CONTAINER_NAME:-ollama-ppc64le}"

if ! command -v "${RUNTIME}" >/dev/null 2>&1; then
  echo "Container runtime not found: ${RUNTIME}"
  exit 1
fi

if ! ${RUNTIME} container exists "${NAME}" >/dev/null 2>&1; then
  echo "Container ${NAME} does not exist. Start it first with ./scripts/ollama_manager.sh start"
  exit 1
fi

if [[ "$(${RUNTIME} inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null || true)" != "true" ]]; then
  echo "Container ${NAME} is not running. Start it first with ./scripts/ollama_manager.sh start"
  exit 1
fi

exec ${RUNTIME} exec -i "${NAME}" ollama create "${MODEL_NAME}" -f - < "${MODELFILE_PATH}"
