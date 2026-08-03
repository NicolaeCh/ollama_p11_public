#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
COMPOSE_FILE="${BASE_DIR}/docker-compose.yml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env and review it." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

RUNTIME="${CONTAINER_RUNTIME:-podman}"
NAME="${CONTAINER_NAME:-ollama-ppc64le}"
THREADS="${OLLAMA_NUM_THREADS:-16}"
if [[ "${OLLAMA_MODELS_DIR:-./models}" = /* ]]; then
  MODELS_DIR="${OLLAMA_MODELS_DIR:-${BASE_DIR}/models}"
else
  MODELS_DIR="${BASE_DIR}/${OLLAMA_MODELS_DIR:-models}"
fi
export OLLAMA_MODELS_DIR="${MODELS_DIR}"
CONTAINER_CPUS="${OLLAMA_CONTAINER_CPUS:-${THREADS}}"
N8N_NETWORK="${N8N_NETWORK_NAME:-n8n-ppc64le_n8n_net}"
LOCAL_NETWORK="${OLLAMA_NETWORK_NAME:-ollama-net-local}"
export OLLAMA_CONTAINER_CPUS="${CONTAINER_CPUS}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ollama-p11}"

say() { printf '%s\n' "$*"; }
usage() {
  cat <<USAGE
Usage: $0 {start|stop|restart|recreate|status|logs|shell|rm|pull-image|config|inspect|cpu-info|verify}
USAGE
}

ensure_runtime() {
  command -v "${RUNTIME}" >/dev/null 2>&1 || {
    say "Container runtime not found: ${RUNTIME}"
    exit 1
  }
}

compose_cmd=()
detect_compose() {
  ensure_runtime
  case "${COMPOSE_COMMAND:-auto}" in
    auto)
      if "${RUNTIME}" compose version >/dev/null 2>&1; then
        compose_cmd=("${RUNTIME}" compose)
      elif [[ "${RUNTIME}" == "podman" ]] && command -v podman-compose >/dev/null 2>&1; then
        compose_cmd=(podman-compose)
      elif [[ "${RUNTIME}" == "docker" ]] && command -v docker-compose >/dev/null 2>&1; then
        compose_cmd=(docker-compose)
      else
        say "No Compose provider found. Install podman-compose or the Podman Compose provider."
        exit 1
      fi
      ;;
    "podman compose") compose_cmd=(podman compose) ;;
    podman-compose) compose_cmd=(podman-compose) ;;
    "docker compose") compose_cmd=(docker compose) ;;
    docker-compose) compose_cmd=(docker-compose) ;;
    *)
      say "Unsupported COMPOSE_COMMAND=${COMPOSE_COMMAND}"
      exit 1
      ;;
  esac
}

compose() {
  if (( ${#compose_cmd[@]} == 0 )); then detect_compose; fi
  (
    cd "${BASE_DIR}"
    "${compose_cmd[@]}" --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
  )
}

network_exists() {
  "${RUNTIME}" network exists "$1" >/dev/null 2>&1
}

preflight() {
  detect_compose
  mkdir -p "${MODELS_DIR}"
  chmod u+rwx "${MODELS_DIR}" 2>/dev/null || true

  [[ "${THREADS}" =~ ^[1-9][0-9]*$ ]] || { say "OLLAMA_NUM_THREADS must be a positive integer"; exit 1; }
  [[ "${CONTAINER_CPUS}" =~ ^[0-9]+([.][0-9]+)?$ ]] || { say "OLLAMA_CONTAINER_CPUS must be numeric"; exit 1; }

  if ! network_exists "${N8N_NETWORK}"; then
    say "Required external network does not exist: ${N8N_NETWORK}"
    say "Create/start the n8n project first, or create it explicitly with:"
    say "  ${RUNTIME} network create ${N8N_NETWORK}"
    exit 1
  fi

  local online
  online="$(nproc 2>/dev/null || echo 1)"
  if (( THREADS > online )); then
    say "WARNING: OLLAMA_NUM_THREADS=${THREADS}, but RHEL reports ${online} online logical CPUs."
  fi
  awk -v quota="${CONTAINER_CPUS}" -v threads="${THREADS}" 'BEGIN { if (quota+0 < threads+0) exit 1 }' || {
    say "OLLAMA_CONTAINER_CPUS (${CONTAINER_CPUS}) must be >= OLLAMA_NUM_THREADS (${THREADS})."
    exit 1
  }
}

wait_healthy() {
  local port="${OLLAMA_PORT:-11434}"
  local host="${OLLAMA_API_HOST:-127.0.0.1}"
  for _ in $(seq 1 60); do
    if curl -fsS "http://${host}:${port}/api/tags" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  say "Ollama did not become reachable at http://${host}:${port}"
  return 1
}

start_service() {
  preflight
  compose up -d ollama
  wait_healthy
  say "Ollama is running. The project clients request ${THREADS} inference threads."
  say "Container CPU quota: ${CONTAINER_CPUS} CPUs"
  say "Networks: ${LOCAL_NETWORK}, ${N8N_NETWORK}"
}

remove_service() {
  detect_compose
  compose down --remove-orphans
}

cpu_info() {
  detect_compose
  say "Configured inference threads: ${THREADS}"
  say "Configured container CPU quota: ${CONTAINER_CPUS}"
  say "Host online logical CPUs: $(nproc 2>/dev/null || echo unknown)"
  if "${RUNTIME}" container exists "${NAME}" >/dev/null 2>&1; then
    "${RUNTIME}" exec "${NAME}" sh -lc \
      'echo "container_nproc=$(nproc)"; grep -E "Cpus_allowed_list|Cpus_allowed" /proc/self/status' || true
  fi
}

verify() {
  preflight
  say "=== Resolved Compose configuration ==="
  compose config >/dev/null
  say "Compose configuration: OK"

  if ! "${RUNTIME}" container exists "${NAME}" >/dev/null 2>&1; then
    say "Container ${NAME} does not exist. Run: $0 start"
    exit 1
  fi

  local running
  running="$("${RUNTIME}" inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null || true)"
  [[ "${running}" == "true" ]] || { say "Container ${NAME} is not running"; exit 1; }

  local networks
  networks="$("${RUNTIME}" inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "${NAME}")"
  say "Attached networks: ${networks}"
  grep -qw "${LOCAL_NETWORK}" <<<"${networks}" || { say "Missing network ${LOCAL_NETWORK}"; exit 1; }
  grep -qw "${N8N_NETWORK}" <<<"${networks}" || { say "Missing network ${N8N_NETWORK}"; exit 1; }

  wait_healthy
  cpu_info
  say "Runtime verification: OK"
  say "For a model-level generation test, run: ./scripts/thread_test.sh <model>"
}

case "${1:-}" in
  start) start_service ;;
  stop) detect_compose; compose stop ollama ;;
  restart) preflight; compose restart ollama; wait_healthy ;;
  recreate) preflight; compose up -d --force-recreate ollama; wait_healthy ;;
  status) detect_compose; compose ps ;;
  logs) detect_compose; compose logs -f ollama ;;
  shell) ensure_runtime; "${RUNTIME}" exec -it "${NAME}" /bin/bash ;;
  rm) remove_service ;;
  pull-image) preflight; compose pull ollama ;;
  config) detect_compose; compose config ;;
  inspect) ensure_runtime; "${RUNTIME}" inspect "${NAME}" ;;
  cpu-info) cpu_info ;;
  verify) verify ;;
  *) usage; exit 1 ;;
esac
