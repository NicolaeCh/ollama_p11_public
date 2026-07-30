#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

RUNTIME="${CONTAINER_RUNTIME:-podman}"
NAME="${CONTAINER_NAME:-ollama-ppc64le}"
IMAGE="${OLLAMA_IMAGE:-quay.io/andre_lutz/ollama-ppc64le}"
PORT="${OLLAMA_PORT:-11434}"
HOST_BIND="${OLLAMA_HOST_BIND:-0.0.0.0}"
MODELS_DIR="${OLLAMA_MODELS_DIR:-${BASE_DIR}/models}"
KEEP_ALIVE="${OLLAMA_KEEP_ALIVE:-10m}"
ORIGINS="${OLLAMA_ORIGINS:-*}"
CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-16384}"
NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-1}"
MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-1}"
MAX_QUEUE="${OLLAMA_MAX_QUEUE:-64}"
NUM_THREADS="${OLLAMA_NUM_THREADS:-16}"
CONTAINER_CPUS="${OLLAMA_CONTAINER_CPUS:-}"
CPUSET_CPUS="${OLLAMA_CPUSET_CPUS:-}"
HTTPS_PROXY_VALUE="${HTTPS_PROXY:-}"
NO_PROXY_VALUE="${NO_PROXY:-127.0.0.1,localhost}"

say() { printf '%s\n' "$*"; }
usage() { echo "Usage: $0 {start|stop|restart|recreate|status|logs|shell|rm|pull-image|inspect|cpu-info}"; }
exists() { ${RUNTIME} container exists "${NAME}" >/dev/null 2>&1; }
running() { [[ "$(${RUNTIME} inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null || true)" == "true" ]]; }
ensure_runtime() { command -v "${RUNTIME}" >/dev/null 2>&1 || { say "Container runtime not found: ${RUNTIME}"; exit 1; }; }
ensure_models_dir() { mkdir -p "${MODELS_DIR}"; chmod u+rwx "${MODELS_DIR}" >/dev/null 2>&1 || true; }

cpu_args=()
[[ -n "${CONTAINER_CPUS}" ]] && cpu_args+=(--cpus "${CONTAINER_CPUS}")
[[ -n "${CPUSET_CPUS}" ]] && cpu_args+=(--cpuset-cpus "${CPUSET_CPUS}")

start_container() {
  ensure_runtime
  ensure_models_dir
  if exists; then
    if running; then say "Container ${NAME} is already running"; return 0; fi
    ${RUNTIME} start "${NAME}"
    say "Container ${NAME} started"
    return 0
  fi

  local host_threads
  host_threads="$(nproc 2>/dev/null || echo 1)"
  if (( NUM_THREADS > host_threads )); then
    say "WARNING: OLLAMA_NUM_THREADS=${NUM_THREADS}, but the host reports only ${host_threads} online logical CPUs."
  fi

  ${RUNTIME} run -d \
    --name "${NAME}" \
    -p "${HOST_BIND}:${PORT}:11434" \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -e OLLAMA_MODELS=/root/.ollama/models \
    -e OLLAMA_KEEP_ALIVE="${KEEP_ALIVE}" \
    -e OLLAMA_ORIGINS="${ORIGINS}" \
    -e OLLAMA_CONTEXT_LENGTH="${CONTEXT_LENGTH}" \
    -e OLLAMA_NUM_PARALLEL="${NUM_PARALLEL}" \
    -e OLLAMA_MAX_LOADED_MODELS="${MAX_LOADED_MODELS}" \
    -e OLLAMA_MAX_QUEUE="${MAX_QUEUE}" \
    -e HTTPS_PROXY="${HTTPS_PROXY_VALUE}" \
    -e NO_PROXY="${NO_PROXY_VALUE}" \
    "${cpu_args[@]}" \
    -v "${MODELS_DIR}:/root/.ollama:Z" \
    --restart unless-stopped \
    "${IMAGE}"

  say "Container ${NAME} created and started"
  say "Inference clients in this project will request ${NUM_THREADS} CPU threads per generation."
}

remove_container() {
  if exists; then
    running && ${RUNTIME} stop "${NAME}" >/dev/null
    ${RUNTIME} rm "${NAME}" >/dev/null
    say "Container ${NAME} removed"
  else
    say "Container ${NAME} does not exist"
  fi
}

cpu_info() {
  ensure_runtime
  say "Project inference threads: ${NUM_THREADS}"
  say "Host online logical CPUs: $(nproc 2>/dev/null || echo unknown)"
  if exists; then
    say "Container CPU visibility:"
    ${RUNTIME} exec "${NAME}" sh -lc 'echo -n "nproc="; nproc; echo "Cpus_allowed_list=$(grep Cpus_allowed_list /proc/self/status | awk "{print \\$2}")"' || true
  fi
}

case "${1:-}" in
  start) start_container ;;
  stop) ensure_runtime; ${RUNTIME} stop "${NAME}" ;;
  restart) ensure_runtime; exists && ${RUNTIME} restart "${NAME}" || start_container ;;
  recreate) ensure_runtime; remove_container; start_container ;;
  status) ensure_runtime; ${RUNTIME} ps -a --filter "name=${NAME}" ;;
  logs) ensure_runtime; ${RUNTIME} logs -f "${NAME}" ;;
  shell) ensure_runtime; ${RUNTIME} exec -it "${NAME}" /bin/bash ;;
  inspect) ensure_runtime; ${RUNTIME} inspect "${NAME}" ;;
  cpu-info) cpu_info ;;
  rm) ensure_runtime; remove_container ;;
  pull-image) ensure_runtime; ${RUNTIME} pull "${IMAGE}" ;;
  *) usage; exit 1 ;;
esac
