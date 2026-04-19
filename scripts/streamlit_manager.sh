#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${BASE_DIR}/.env"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

PROJECT_DIR="${PROJECT_DIR:-${BASE_DIR}}"
STREAMLIT_DIR="${PROJECT_DIR}/streamlit"
LOGS_DIR="${PROJECT_DIR}/logs"
VENV_DIR="${PROJECT_DIR}/venv"
STREAMLIT_HOST="${STREAMLIT_HOST:-0.0.0.0}"
STREAMLIT_PORT="${STREAMLIT_PORT:-8505}"
PID_FILE="${LOGS_DIR}/streamlit.pid"
LOG_FILE="${LOGS_DIR}/streamlit.log"
APP_FILE="${STREAMLIT_DIR}/ollama_chat.py"

usage() {
  cat <<USAGE
Usage: $0 {start|stop|restart|status|logs}
USAGE
}

is_running() {
  [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1
}

start_app() {
  mkdir -p "${LOGS_DIR}"

  if [[ ! -x "${VENV_DIR}/bin/streamlit" ]]; then
    echo "Streamlit binary not found in ${VENV_DIR}. Run ./setup_environment.sh first."
    exit 1
  fi

  if is_running; then
    echo "Streamlit is already running with PID $(cat "${PID_FILE}")"
    exit 0
  fi

  cd "${STREAMLIT_DIR}"
  nohup "${VENV_DIR}/bin/streamlit" run "${APP_FILE}" \
    --server.address "${STREAMLIT_HOST}" \
    --server.port "${STREAMLIT_PORT}" \
    --server.headless true \
    > "${LOG_FILE}" 2>&1 &
  echo $! > "${PID_FILE}"
  sleep 2

  if is_running; then
    echo "Streamlit started on ${STREAMLIT_HOST}:${STREAMLIT_PORT} with PID $(cat "${PID_FILE}")"
    echo "Log file: ${LOG_FILE}"
  else
    echo "Streamlit failed to start. Check ${LOG_FILE}"
    rm -f "${PID_FILE}"
    exit 1
  fi
}

stop_app() {
  if ! [[ -f "${PID_FILE}" ]]; then
    echo "Streamlit is not running"
    exit 0
  fi

  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" >/dev/null 2>&1; then
    kill "${PID}"
    sleep 2
    if kill -0 "${PID}" >/dev/null 2>&1; then
      kill -9 "${PID}" >/dev/null 2>&1 || true
    fi
  fi
  rm -f "${PID_FILE}"
  echo "Streamlit stopped"
}

status_app() {
  if is_running; then
    echo "Streamlit is running with PID $(cat "${PID_FILE}") on ${STREAMLIT_HOST}:${STREAMLIT_PORT}"
  else
    echo "Streamlit is not running"
  fi
}

case "${1:-}" in
  start)
    start_app
    ;;
  stop)
    stop_app
    ;;
  restart)
    stop_app || true
    start_app
    ;;
  status)
    status_app
    ;;
  logs)
    mkdir -p "${LOGS_DIR}"
    touch "${LOG_FILE}"
    tail -f "${LOG_FILE}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
