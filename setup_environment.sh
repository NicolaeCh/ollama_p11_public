#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="${PROJECT_DIR}/models"
LOGS_DIR="${PROJECT_DIR}/logs"
MODELFILES_DIR="${PROJECT_DIR}/modelfiles"
ENV_FILE="${PROJECT_DIR}/.env"
IMAGE="icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6"
FURY="--prefer-binary --extra-index-url=https://repo.fury.io/mgiessing"

say() { printf '%s\n' "$*"; }

say "=================================================="
say "Ollama Environment Setup - IBM Power ppc64le"
say "Project directory: ${PROJECT_DIR}"
say "=================================================="

ARCH="$(uname -m)"
[[ "${ARCH}" == "ppc64le" ]] || say "WARNING: detected ${ARCH}; expected ppc64le"

if command -v podman >/dev/null 2>&1; then
  RUNTIME="podman"
elif command -v docker >/dev/null 2>&1; then
  RUNTIME="docker"
else
  say "No container runtime found. Installing Podman..."
  sudo dnf install -y podman
  RUNTIME="podman"
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
  cat > "${ENV_FILE}" <<ENV
CONTAINER_RUNTIME=${RUNTIME}
CONTAINER_NAME=ollama-ppc64le
OLLAMA_IMAGE=${IMAGE}
OLLAMA_HOST_BIND=0.0.0.0
OLLAMA_API_HOST=127.0.0.1
OLLAMA_PORT=11434
STREAMLIT_HOST=0.0.0.0
STREAMLIT_PORT=8505
PROJECT_DIR=${PROJECT_DIR}
OLLAMA_MODELS_DIR=${MODELS_DIR}
OLLAMA_KEEP_ALIVE=10m
OLLAMA_ORIGINS=*
OLLAMA_CONTEXT_LENGTH=16384
OLLAMA_NUM_THREADS=16
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_MAX_QUEUE=64
OLLAMA_CONTAINER_CPUS=
OLLAMA_CPUSET_CPUS=
HTTPS_PROXY=
NO_PROXY=127.0.0.1,localhost
ENV
  say "Created ${ENV_FILE}"
else
  say "Keeping existing ${ENV_FILE}"
  say "Ensure it contains OLLAMA_NUM_THREADS=16 or the desired value."
fi

cat > "${PROJECT_DIR}/.streamlit/config.toml" <<'TOML'
[server]
headless = true
address = "0.0.0.0"
port = 8505

[browser]
gatherUsageStats = false
TOML

say "Pulling ${IMAGE}"
"${RUNTIME}" pull "${IMAGE}"

say "Setup complete"
say "Edit ${ENV_FILE} and set OLLAMA_NUM_THREADS to the desired inference thread count."
say "Start with: ${PROJECT_DIR}/scripts/ollama_manager.sh start"
say "Then:       ${PROJECT_DIR}/scripts/streamlit_manager.sh start"
