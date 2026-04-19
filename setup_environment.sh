#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${HOME}/ollama-project"
MODELS_DIR="${PROJECT_DIR}/models"
SCRIPTS_DIR="${PROJECT_DIR}/scripts"
STREAMLIT_DIR="${PROJECT_DIR}/streamlit"
STREAMLIT_CFG_DIR="${PROJECT_DIR}/.streamlit"
LOGS_DIR="${PROJECT_DIR}/logs"
MODELFILES_DIR="${PROJECT_DIR}/modelfiles"
TEMPLATES_DIR="${PROJECT_DIR}/templates"
ENV_FILE="${PROJECT_DIR}/.env"
IMAGE="icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6"
FURY="--prefer-binary --extra-index-url=https://repo.fury.io/mgiessing"
STREAMLIT_PORT="8505"
STREAMLIT_HOST="0.0.0.0"

say() { printf '%s\n' "$*"; }
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

say "=================================================="
say "Ollama Testing Environment Setup"
say "IBM Power / Linux / ppc64le"
say "=================================================="

ARCH="$(uname -m)"
if [[ "${ARCH}" != "ppc64le" ]]; then
  say "WARNING: detected architecture ${ARCH}, expected ppc64le"
fi

if command -v podman >/dev/null 2>&1; then
  RUNTIME="podman"
elif command -v docker >/dev/null 2>&1; then
  RUNTIME="docker"
else
  say "No container runtime found. Installing Podman..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y podman
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y podman
  else
    say "Could not auto-install Podman. Install Podman or Docker manually."
    exit 1
  fi
  RUNTIME="podman"
fi

if ! command -v python3 >/dev/null 2>&1; then
  say "Python 3 is required. Install python3 and retry."
  exit 1
fi

mkdir -p "${MODELS_DIR}" "${SCRIPTS_DIR}" "${STREAMLIT_DIR}" "${STREAMLIT_CFG_DIR}" "${LOGS_DIR}" "${MODELFILES_DIR}" "${TEMPLATES_DIR}"
chmod 700 "${MODELS_DIR}" >/dev/null 2>&1 || true

python3 -m venv "${PROJECT_DIR}/venv"
source "${PROJECT_DIR}/venv/bin/activate"
pip install --upgrade pip
pip install -r "${SRC_DIR}/streamlit/requirements.txt" ${FURY}

cp -f "${SRC_DIR}/scripts/"*.sh "${SCRIPTS_DIR}/"
cp -f "${SRC_DIR}/streamlit/"* "${STREAMLIT_DIR}/"
cp -f "${SRC_DIR}/templates/"* "${TEMPLATES_DIR}/"
cp -f "${SRC_DIR}/README.md" "${PROJECT_DIR}/README.md"
cp -f "${SRC_DIR}/DEPLOYMENT_GUIDE.md" "${PROJECT_DIR}/DEPLOYMENT_GUIDE.md"
cp -f "${SRC_DIR}/QUICK_REFERENCE.md" "${PROJECT_DIR}/QUICK_REFERENCE.md"
cp -f "${SRC_DIR}/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cp -f "${SRC_DIR}/.env.example" "${PROJECT_DIR}/.env.example"
cp -f "${SRC_DIR}/setup_environment.sh" "${PROJECT_DIR}/setup_environment.sh"
chmod +x "${SCRIPTS_DIR}"/*.sh "${PROJECT_DIR}/setup_environment.sh"

cat > "${ENV_FILE}" <<ENV
CONTAINER_RUNTIME=${RUNTIME}
CONTAINER_NAME=ollama-ppc64le
OLLAMA_IMAGE=${IMAGE}
OLLAMA_HOST_BIND=127.0.0.1
OLLAMA_PORT=11434
STREAMLIT_HOST=${STREAMLIT_HOST}
STREAMLIT_PORT=${STREAMLIT_PORT}
PROJECT_DIR=${PROJECT_DIR}
OLLAMA_MODELS_DIR=${MODELS_DIR}
OLLAMA_KEEP_ALIVE=10m
OLLAMA_ORIGINS=
HTTPS_PROXY=
NO_PROXY=127.0.0.1,localhost
ENV

cat > "${STREAMLIT_DIR}/config.yaml" <<ENV
project_dir: ${PROJECT_DIR}
models_dir: ${MODELS_DIR}
logs_dir: ${LOGS_DIR}
modelfiles_dir: ${MODELFILES_DIR}
container_name: ollama-ppc64le
api_scheme: http
host_bind: 127.0.0.1
container_port: 11434
streamlit_host: ${STREAMLIT_HOST}
streamlit_port: ${STREAMLIT_PORT}
default_model: ""
default_temperature: 0.7
default_num_predict: 512
default_keep_alive: 10m
ENV

cat > "${STREAMLIT_CFG_DIR}/config.toml" <<ENV
[server]
headless = true
address = "${STREAMLIT_HOST}"
port = ${STREAMLIT_PORT}

[browser]
gatherUsageStats = false
ENV

say "Pulling IBM Power Ollama image..."
if "${RUNTIME}" pull "${IMAGE}"; then
  say "Image pulled successfully."
else
  say "Image pull failed. You can retry later with: ${RUNTIME} pull ${IMAGE}"
fi

say ""
say "Setup complete"
say "Project directory: ${PROJECT_DIR}"
say "Runtime: ${RUNTIME}"
say "Next steps:"
say "  source ${PROJECT_DIR}/venv/bin/activate"
say "  cd ${PROJECT_DIR}"
say "  ./scripts/ollama_manager.sh start"
say "  ./scripts/pull_model.sh gemma3:4b-it-qat"
say "  ./scripts/streamlit_manager.sh start"
say "  ./scripts/streamlit_manager.sh status"
say "  ./scripts/streamlit_manager.sh logs"
