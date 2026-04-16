#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

RUNTIME="${CONTAINER_RUNTIME:-podman}"
NAME="${CONTAINER_NAME:-ollama-ppc64le}"
IMAGE="${OLLAMA_IMAGE:-icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6}"
PORT="${OLLAMA_PORT:-11434}"
HOST_BIND="${OLLAMA_HOST_BIND:-127.0.0.1}"
MODELS_DIR="${OLLAMA_MODELS_DIR:-${BASE_DIR}/models}"
KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:-10m}"
ORIGINS="${OLLAMA_ORIGINS:-}"
HTTPS_PROXY_VALUE="${HTTPS_PROXY:-}"
NO_PROXY_VALUE="${NO_PROXY:-127.0.0.1,localhost}"

usage() {
  cat <<USAGE
Usage: $0 {start|stop|restart|status|logs|shell|rm|pull-image}
USAGE
}

exists() {
  ${RUNTIME} container exists "${NAME}" >/dev/null 2>&1
}

running() {
  [[ "$(${RUNTIME} inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null || true)" == "true" ]]
}

start_container() {
  mkdir -p "${MODELS_DIR}"
  if exists; then
    if running; then
      echo "Container ${NAME} is already running"
      return 0
    fi
    ${RUNTIME} start "${NAME}"
    echo "Container ${NAME} started"
    return 0
  fi

  ${RUNTIME} run -d \
    --name "${NAME}" \
    -p "${HOST_BIND}:${PORT}:11434" \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -e OLLAMA_MODELS=/root/.ollama/models \
    -e OLLAMA_KEEP_ALIVE="${KEEP_ALIVE}" \
    -e OLLAMA_ORIGINS="${ORIGINS}" \
    -e HTTPS_PROXY="${HTTPS_PROXY_VALUE}" \
    -e NO_PROXY="${NO_PROXY_VALUE}" \
    -v "${MODELS_DIR}:/root/.ollama:Z" \
    --restart unless-stopped \
    "${IMAGE}"

  echo "Container ${NAME} created and started"
}

case "${1:-}" in
  start)
    start_container
    ;;
  stop)
    ${RUNTIME} stop "${NAME}"
    ;;
  restart)
    if exists; then
      ${RUNTIME} restart "${NAME}"
    else
      start_container
    fi
    ;;
  status)
    ${RUNTIME} ps -a --filter "name=${NAME}"
    ;;
  logs)
    ${RUNTIME} logs -f "${NAME}"
    ;;
  shell)
    ${RUNTIME} exec -it "${NAME}" /bin/bash
    ;;
  rm)
    if exists; then
      if running; then
        ${RUNTIME} stop "${NAME}"
      fi
      ${RUNTIME} rm "${NAME}"
    fi
    ;;
  pull-image)
    ${RUNTIME} pull "${IMAGE}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
