#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="${PROJECT_DIR}/models"
LOGS_DIR="${PROJECT_DIR}/logs"
MODELFILES_DIR="${PROJECT_DIR}/modelfiles"
ENV_FILE="${PROJECT_DIR}/.env"
FURY="--prefer-binary --extra-index-url=https://repo.fury.io/mgiessing"
DEFAULT_IMAGE="icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6"

say() { printf '%s\n' "$*"; }

say "=================================================="
say "Ollama Environment Setup - IBM Power ppc64le"
say "Project directory: ${PROJECT_DIR}"
say "=================================================="

ARCH="$(uname -m)"
[[ "${ARCH}" == "ppc64le" ]] || say "WARNING: detected ${ARCH}; expected ppc64le"

if command -v podman >/dev/null 2>&1; then
  RUNTIME=podman
elif command -v docker >/dev/null 2>&1; then
  RUNTIME=docker
else
  say "No container runtime found. Installing Podman..."
  sudo dnf install -y podman
  RUNTIME=podman
fi

if [[ "${RUNTIME}" == "podman" ]] && ! podman compose version >/dev/null 2>&1 && ! command -v podman-compose >/dev/null 2>&1; then
  say "Installing podman-compose..."
  sudo dnf install -y podman-compose
fi

command -v python3 >/dev/null 2>&1 || { say "Python 3 is required"; exit 1; }
mkdir -p "${MODELS_DIR}" "${LOGS_DIR}" "${MODELFILES_DIR}" "${PROJECT_DIR}/.streamlit"
chmod 700 "${MODELS_DIR}" >/dev/null 2>&1 || true
chmod +x "${PROJECT_DIR}/scripts/"*.sh "${PROJECT_DIR}/setup_environment.sh"

if [[ ! -d "${PROJECT_DIR}/venv" ]]; then
  python3 -m venv "${PROJECT_DIR}/venv"
fi
source "${PROJECT_DIR}/venv/bin/activate"
python -m pip install --upgrade pip
# shellcheck disable=SC2086
pip install -r "${PROJECT_DIR}/streamlit/requirements.txt" ${FURY}

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${PROJECT_DIR}/.env.example" "${ENV_FILE}"
  # Absolute model path avoids ambiguity across Compose providers.
  sed -i "s|^OLLAMA_MODELS_DIR=.*|OLLAMA_MODELS_DIR=${MODELS_DIR}|" "${ENV_FILE}"
  sed -i "s|^CONTAINER_RUNTIME=.*|CONTAINER_RUNTIME=${RUNTIME}|" "${ENV_FILE}"
  sed -i "s|^OLLAMA_IMAGE=.*|OLLAMA_IMAGE=${DEFAULT_IMAGE}|" "${ENV_FILE}"
  say "Created ${ENV_FILE}"
else
  say "Keeping existing ${ENV_FILE}"
fi

cat > "${PROJECT_DIR}/.streamlit/config.toml" <<'TOML'
[server]
headless = true
address = "0.0.0.0"
port = 8505

[browser]
gatherUsageStats = false
TOML

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

THREADS="${OLLAMA_NUM_THREADS:-16}"
CPUS="${OLLAMA_CONTAINER_CPUS:-${THREADS}}"
N8N_NETWORK="${N8N_NETWORK_NAME:-n8n-ppc64le_n8n_net}"

if ! "${RUNTIME}" network exists "${N8N_NETWORK}" >/dev/null 2>&1; then
  say "WARNING: external network ${N8N_NETWORK} does not exist."
  say "Start the n8n stack first or create it with: ${RUNTIME} network create ${N8N_NETWORK}"
fi

say "Pulling ${OLLAMA_IMAGE:-${DEFAULT_IMAGE}}"
"${RUNTIME}" pull "${OLLAMA_IMAGE:-${DEFAULT_IMAGE}}"

say "Setup complete"
say "Inference threads: ${THREADS}"
say "Container CPU quota: ${CPUS}"
say "Start Ollama:   ${PROJECT_DIR}/scripts/ollama_manager.sh start"
say "Verify runtime: ${PROJECT_DIR}/scripts/ollama_manager.sh verify"
say "Start UI:       ${PROJECT_DIR}/scripts/streamlit_manager.sh start"
