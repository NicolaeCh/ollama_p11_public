#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <model-name> [prompt]"
  exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] || { echo "Missing ${ENV_FILE}"; exit 1; }
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

MODEL="$1"
PROMPT="${2:-Write a detailed technical explanation of simultaneous multithreading, matrix multiplication, memory bandwidth and CPU inference on IBM Power. Use at least 1200 words.}"
HOST="${OLLAMA_API_HOST:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"
THREADS="${OLLAMA_NUM_THREADS:-16}"
CTX="${OLLAMA_CONTEXT_LENGTH:-16384}"
RUNTIME="${CONTAINER_RUNTIME:-podman}"
NAME="${CONTAINER_NAME:-ollama-ppc64le}"

PAYLOAD="$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"prompt":sys.argv[2],"stream":True,"options":{"num_thread":int(sys.argv[3]),"num_ctx":int(sys.argv[4]),"num_predict":1024}}))' "$MODEL" "$PROMPT" "$THREADS" "$CTX")"

echo "Model:                 ${MODEL}"
echo "Requested num_thread:  ${THREADS}"
echo "Context length:        ${CTX}"
echo "Container CPU quota:   ${OLLAMA_CONTAINER_CPUS:-${THREADS}}"
echo "Watch CPU in another terminal with: nmon"
echo

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT
curl -fsS -N "http://${HOST}:${PORT}/api/generate" \
  -H 'Content-Type: application/json' \
  -d "${PAYLOAD}" > "${TMP}" &
CURL_PID=$!

peak_tasks=0
while kill -0 "${CURL_PID}" >/dev/null 2>&1; do
  tasks="$(${RUNTIME} exec "${NAME}" sh -lc 'for p in /proc/[0-9]*; do [ -r "$p/comm" ] || continue; c=$(cat "$p/comm" 2>/dev/null); case "$c" in ollama*|runner*|llama*) ls "$p/task" 2>/dev/null | wc -l;; esac; done | awk '\''{s+=$1} END {print s+0}'\''' 2>/dev/null || echo 0)"
  [[ "${tasks}" =~ ^[0-9]+$ ]] || tasks=0
  (( tasks > peak_tasks )) && peak_tasks=${tasks}
  sleep 0.25
done
wait "${CURL_PID}"

echo "Peak Ollama/runner OS tasks observed: ${peak_tasks}"
echo "Request completed successfully with options.num_thread=${THREADS}."
echo "Note: OS task count includes service/helper threads and is not identical to active inference threads."
