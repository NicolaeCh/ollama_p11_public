#!/usr/bin/env bash
set -euo pipefail

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

exec ${RUNTIME} exec -i "${NAME}" ollama list
