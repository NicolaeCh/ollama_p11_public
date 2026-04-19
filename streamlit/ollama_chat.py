"""Streamlit UI for local Ollama testing on IBM Power."""
from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd
import requests
import streamlit as st
import yaml

PROJECT_DIR = Path.home() / "ollama-project"
CONFIG_FILE = PROJECT_DIR / "streamlit" / "config.yaml"
SCRIPTS_DIR = PROJECT_DIR / "scripts"


def load_config() -> Dict[str, Any]:
    default = {
        "project_dir": str(PROJECT_DIR),
        "host_bind": "127.0.0.1",
        "container_port": 11434,
        "streamlit_host": "0.0.0.0",
        "streamlit_port": 8505,
        "default_model": "",
        "default_temperature": 0.7,
        "default_num_predict": 512,
        "default_keep_alive": "10m",
    }
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, "r", encoding="utf-8") as fh:
            loaded = yaml.safe_load(fh) or {}
        default.update(loaded)
    return default


CONFIG = load_config()
OLLAMA_BASE_URL = f"{CONFIG.get('api_scheme', 'http')}://{CONFIG['host_bind']}:{CONFIG['container_port']}/api"

st.set_page_config(
    page_title="Ollama Testing Interface - IBM Power",
    page_icon="🦙",
    layout="wide",
    initial_sidebar_state="expanded",
)


def api_get(path: str, timeout: int = 10) -> Optional[Dict[str, Any]]:
    try:
        response = requests.get(f"{OLLAMA_BASE_URL}{path}", timeout=timeout)
        response.raise_for_status()
        return response.json()
    except requests.RequestException:
        return None


def api_post(path: str, payload: Dict[str, Any], timeout: int = 120) -> Optional[Dict[str, Any]]:
    try:
        response = requests.post(f"{OLLAMA_BASE_URL}{path}", json=payload, timeout=timeout)
        response.raise_for_status()
        if response.text.strip():
            return response.json()
        return {}
    except requests.RequestException:
        return None


def check_server() -> Dict[str, Any]:
    tags = api_get("/tags", timeout=5)
    ps = api_get("/ps", timeout=5)
    healthy = tags is not None
    return {
        "healthy": healthy,
        "models": (tags or {}).get("models", []),
        "running": (ps or {}).get("models", []),
    }


def container_status() -> Dict[str, str]:
    for runtime in ("podman", "docker"):
        try:
            result = subprocess.run(
                [runtime, "ps", "-a", "--filter", "name=ollama-ppc64le", "--format", "{{.Status}}"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0 and result.stdout.strip():
                return {"runtime": runtime, "status": result.stdout.strip()}
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue
    return {"runtime": "n/a", "status": "Not found"}


def run_script(script: str, *args: str, timeout: int = 30) -> subprocess.CompletedProcess[str]:
    script_path = SCRIPTS_DIR / script
    return subprocess.run(
        ["bash", str(script_path), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def list_models() -> List[Dict[str, Any]]:
    data = api_get("/tags") or {}
    return data.get("models", [])


def list_running_models() -> List[Dict[str, Any]]:
    data = api_get("/ps") or {}
    return data.get("models", [])


def pull_model(model_name: str) -> tuple[bool, str]:
    try:
        result = run_script("pull_model.sh", model_name, timeout=7200)
        if result.returncode == 0:
            return True, result.stdout.strip() or f"Pulled {model_name}"
        return False, result.stderr.strip() or result.stdout.strip() or "Model pull failed"
    except Exception as exc:
        return False, str(exc)


def delete_model(model_name: str) -> tuple[bool, str]:
    try:
        result = run_script("delete_model.sh", model_name, timeout=300)
        if result.returncode == 0:
            return True, result.stdout.strip() or f"Deleted {model_name}"
        return False, result.stderr.strip() or result.stdout.strip() or "Delete failed"
    except Exception as exc:
        return False, str(exc)


def create_model(new_name: str, modelfile_path: str) -> tuple[bool, str]:
    try:
        result = run_script("create_model.sh", new_name, modelfile_path, timeout=1800)
        if result.returncode == 0:
            return True, result.stdout.strip() or f"Created model {new_name}"
        return False, result.stderr.strip() or result.stdout.strip() or "Create failed"
    except Exception as exc:
        return False, str(exc)


def chat_once(model: str, messages: List[Dict[str, str]], temperature: float, num_predict: int, keep_alive: str) -> Dict[str, Any]:
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": temperature,
            "num_predict": num_predict,
        },
        "keep_alive": keep_alive,
    }
    started = time.perf_counter()
    result = api_post("/chat", payload, timeout=1800)
    elapsed = time.perf_counter() - started
    if result is None:
        raise RuntimeError("Ollama API request failed")

    eval_count = result.get("eval_count", 0) or 0
    eval_duration = result.get("eval_duration", 0) or 0
    prompt_eval_count = result.get("prompt_eval_count", 0) or 0
    prompt_eval_duration = result.get("prompt_eval_duration", 0) or 0

    tps = 0.0
    if eval_count and eval_duration:
        tps = eval_count / (eval_duration / 1_000_000_000)

    ttft = 0.0
    if prompt_eval_duration:
        ttft = prompt_eval_duration / 1_000_000_000

    return {
        "content": result.get("message", {}).get("content", ""),
        "total_time": elapsed,
        "ttft": ttft,
        "tps": tps,
        "prompt_tokens": prompt_eval_count,
        "completion_tokens": eval_count,
        "raw": result,
    }


def metrics_frame(rows: List[Dict[str, Any]]) -> pd.DataFrame:
    if not rows:
        return pd.DataFrame(
            columns=["timestamp", "model", "ttft_s", "tps", "total_s", "prompt_tokens", "completion_tokens"]
        )
    return pd.DataFrame(rows)


def format_size(num_bytes: int) -> str:
    value = float(num_bytes)
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if value < 1024 or unit == "TB":
            return f"{value:.2f} {unit}"
        value /= 1024
    return f"{num_bytes} B"


def main() -> None:
    if "messages" not in st.session_state:
        st.session_state.messages = []
    if "perf_log" not in st.session_state:
        st.session_state.perf_log = []

    status = check_server()
    cstatus = container_status()
    models = list_models()
    running_models = list_running_models()

    with st.sidebar:
        st.title("🦙 Ollama Testing")
        st.caption("IBM Power / ppc64le")
        st.divider()

        st.subheader("Server status")
        if status["healthy"]:
            st.success("Ollama API reachable")
        else:
            st.error("Ollama API offline")
        st.caption(f"Container: {cstatus['status']} ({cstatus['runtime']})")
        st.code(OLLAMA_BASE_URL)
        st.caption(f"Streamlit service port: {CONFIG['streamlit_port']}")

        col1, col2 = st.columns(2)
        with col1:
            if st.button("Start", use_container_width=True):
                result = run_script("ollama_manager.sh", "start")
                st.info(result.stdout or result.stderr)
                st.rerun()
        with col2:
            if st.button("Restart", use_container_width=True):
                result = run_script("ollama_manager.sh", "restart")
                st.info(result.stdout or result.stderr)
                st.rerun()

        col3, col4 = st.columns(2)
        with col3:
            if st.button("Stop", use_container_width=True):
                result = run_script("ollama_manager.sh", "stop")
                st.info(result.stdout or result.stderr)
                st.rerun()
        with col4:
            if st.button("Refresh", use_container_width=True):
                st.rerun()

        st.divider()
        st.subheader("Model operations")
        model_to_pull = st.text_input("Pull model", placeholder="gemma3:4b-it-qat")
        if st.button("Pull", use_container_width=True):
            if model_to_pull.strip():
                ok, msg = pull_model(model_to_pull.strip())
                st.success(msg) if ok else st.error(msg)
                st.rerun()

        available_names = [m.get("name", "") for m in models]
        model_to_delete = st.selectbox("Delete model", [""] + available_names)
        if st.button("Delete selected model", use_container_width=True):
            if model_to_delete:
                ok, msg = delete_model(model_to_delete)
                st.success(msg) if ok else st.error(msg)
                st.rerun()

        st.divider()
        st.subheader("Create custom model")
        new_model_name = st.text_input("New model name", placeholder="granite-custom")
        modelfile_path = st.text_input(
            "Modelfile path",
            value=str(PROJECT_DIR / "modelfiles" / "custom.Modelfile"),
        )
        if st.button("Create from Modelfile", use_container_width=True):
            ok, msg = create_model(new_model_name.strip(), modelfile_path.strip())
            st.success(msg) if ok else st.error(msg)
            st.rerun()

        st.divider()
        st.subheader("Inference parameters")
        selected_model = st.selectbox(
            "Model",
            [""] + available_names,
            index=0,
            help="Choose a locally available Ollama model",
        )
        temperature = st.slider("Temperature", 0.0, 2.0, float(CONFIG["default_temperature"]), 0.1)
        num_predict = st.slider("Max tokens", 32, 4096, int(CONFIG["default_num_predict"]), 32)
        keep_alive = st.text_input("Keep alive", value=str(CONFIG["default_keep_alive"]))

    st.title("Ollama Chat Interface")
    st.caption("Local model testing and lightweight benchmarking for IBM Power")

    tab1, tab2, tab3 = st.tabs(["Chat", "Models", "Performance"])

    with tab1:
        if not selected_model:
            st.info("Select a local model from the sidebar to start chatting.")
        else:
            for msg in st.session_state.messages:
                with st.chat_message(msg["role"]):
                    st.markdown(msg["content"])

            prompt = st.chat_input(f"Send a prompt to {selected_model}")
            if prompt:
                user_msg = {"role": "user", "content": prompt}
                st.session_state.messages.append(user_msg)
                with st.chat_message("user"):
                    st.markdown(prompt)
                with st.chat_message("assistant"):
                    with st.spinner("Generating response..."):
                        try:
                            result = chat_once(
                                selected_model,
                                st.session_state.messages,
                                temperature,
                                num_predict,
                                keep_alive,
                            )
                            answer = result["content"]
                            st.markdown(answer)
                            st.caption(
                                f"TTFT: {result['ttft']:.2f}s | TPS: {result['tps']:.1f} | Total: {result['total_time']:.2f}s | "
                                f"Prompt tokens: {result['prompt_tokens']} | Completion tokens: {result['completion_tokens']}"
                            )
                            st.session_state.messages.append({"role": "assistant", "content": answer})
                            st.session_state.perf_log.append(
                                {
                                    "timestamp": pd.Timestamp.now().isoformat(),
                                    "model": selected_model,
                                    "ttft_s": result["ttft"],
                                    "tps": result["tps"],
                                    "total_s": result["total_time"],
                                    "prompt_tokens": result["prompt_tokens"],
                                    "completion_tokens": result["completion_tokens"],
                                }
                            )
                        except Exception as exc:
                            st.error(str(exc))

            col1, col2 = st.columns(2)
            with col1:
                if st.button("Clear chat", use_container_width=True):
                    st.session_state.messages = []
                    st.rerun()
            with col2:
                if st.button("Warm model", use_container_width=True):
                    try:
                        result = chat_once(selected_model, [{"role": "user", "content": "Reply with OK."}], 0.0, 8, keep_alive)
                        st.success(f"Model warmed. Response: {result['content']}")
                    except Exception as exc:
                        st.error(str(exc))

    with tab2:
        st.subheader("Installed models")
        if models:
            table_rows = []
            for model in models:
                table_rows.append(
                    {
                        "name": model.get("name", ""),
                        "size": format_size(model.get("size", 0) or 0),
                        "modified": model.get("modified_at", ""),
                        "digest": model.get("digest", "")[:16],
                    }
                )
            st.dataframe(pd.DataFrame(table_rows), use_container_width=True, hide_index=True)
        else:
            st.info("No local models found.")

        st.subheader("Running models")
        if running_models:
            running_rows = []
            for model in running_models:
                running_rows.append(
                    {
                        "name": model.get("name", ""),
                        "size": format_size(model.get("size", 0) or 0),
                        "processor": model.get("details", {}).get("family", ""),
                        "expires_at": model.get("expires_at", ""),
                    }
                )
            st.dataframe(pd.DataFrame(running_rows), use_container_width=True, hide_index=True)
        else:
            st.info("No models currently loaded in memory.")

    with tab3:
        st.subheader("Performance history")
        perf_df = metrics_frame(st.session_state.perf_log)
        if perf_df.empty:
            st.info("No performance samples yet. Run a few prompts first.")
        else:
            st.dataframe(perf_df, use_container_width=True, hide_index=True)
            st.line_chart(perf_df.set_index("timestamp")[["ttft_s", "tps", "total_s"]])
            with st.expander("Latest raw response"):
                st.code(json.dumps(st.session_state.perf_log[-1], indent=2), language="json")


if __name__ == "__main__":
    main()
