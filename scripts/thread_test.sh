#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then echo "Usage: $0 <model-name> [prompt]"; exit 1; fi
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "${BASE_DIR}/.env" ]] && source "${BASE_DIR}/.env"
MODEL="$1"
PROMPT="${2:-Explain in detail how CPU multithreading improves matrix multiplication.}"
HOST="${OLLAMA_API_HOST:-127.0.0.1}"
PORT="${OLLAMA_PORT:-11434}"
THREADS="${OLLAMA_NUM_THREADS:-16}"
CTX="${OLLAMA_CONTEXT_LENGTH:-16384}"
echo "Requesting model=${MODEL}, num_thread=${THREADS}, num_ctx=${CTX}"
curl -fsS "http://${HOST}:${PORT}/api/generate" \
  -H 'Content-Type: application/json' \
  -d "$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"prompt":sys.argv[2],"stream":False,"options":{"num_thread":int(sys.argv[3]),"num_ctx":int(sys.argv[4]),"num_predict":512}}))' "$MODEL" "$PROMPT" "$THREADS" "$CTX")"
echo
