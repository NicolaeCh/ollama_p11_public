#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${HOME}/ollama-project"
MODELS_DIR="${PROJECT_DIR}/models"
SCRIPTS_DIR="${PROJECT_DIR}/scripts"
STREAMLIT_DIR="${PROJECT_DIR}/streamlit"
LOGS_DIR="${PROJECT_DIR}/logs"
MODELFILES_DIR="${PROJECT_DIR}/modelfiles"
TEMPLATES_DIR="${PROJECT_DIR}/templates"
ENV_FILE="${PROJECT_DIR}/.env"
IMAGE="icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6"
FURY="--prefer-binary --extra-index-url=https://repo.fury.io/mgiessing"

say() { printf '%s\n' "$*"; }

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

mkdir -p "${MODELS_DIR}" "${SCRIPTS_DIR}" "${STREAMLIT_DIR}" "${LOGS_DIR}" "${MODELFILES_DIR}" "${TEMPLATES_DIR}"

python3 -m venv "${PROJECT_DIR}/venv"
source "${PROJECT_DIR}/venv/bin/activate"
pip install --upgrade pip
pip install -r "$(cd "$(dirname "$0")" && pwd)/streamlit/requirements.txt"   $FURY

cp -f "$(cd "$(dirname "$0")" && pwd)/scripts/"*.sh "${SCRIPTS_DIR}/"
cp -f "$(cd "$(dirname "$0")" && pwd)/streamlit/"* "${STREAMLIT_DIR}/"
cp -f "$(cd "$(dirname "$0")" && pwd)/templates/"* "${TEMPLATES_DIR}/"
cp -f "$(cd "$(dirname "$0")" && pwd)/README.md" "${PROJECT_DIR}/README.md"
cp -f "$(cd "$(dirname "$0")" && pwd)/DEPLOYMENT_GUIDE.md" "${PROJECT_DIR}/DEPLOYMENT_GUIDE.md"
cp -f "$(cd "$(dirname "$0")" && pwd)/QUICK_REFERENCE.md" "${PROJECT_DIR}/QUICK_REFERENCE.md"
cp -f "$(cd "$(dirname "$0")" && pwd)/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cp -f "$(cd "$(dirname "$0")" && pwd)/.env.example" "${PROJECT_DIR}/.env.example"

chmod +x "${SCRIPTS_DIR}"/*.sh

cat > "${ENV_FILE}" <<ENV
CONTAINER_RUNTIME=${RUNTIME}
CONTAINER_NAME=ollama-ppc64le
OLLAMA_IMAGE=${IMAGE}
OLLAMA_HOST_BIND=127.0.0.1
OLLAMA_PORT=11434
STREAMLIT_PORT=8501
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
streamlit_host: 0.0.0.0
streamlit_port: 8501
default_model: ""
default_temperature: 0.7
default_num_predict: 512
default_keep_alive: 10m
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
say "  ./scripts/pull_model.sh granite3.3:8b"
say "  cd streamlit && streamlit run ollama_chat.py --server.port 8501"
