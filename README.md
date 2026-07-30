# Ollama on IBM Power (ppc64le)

A deployable Ollama environment for IBM Power Linux using Podman, the IBM Power Ollama container, a streaming Streamlit chat interface, persistent model storage, and environment-controlled CPU inference threads.

## Components

- Ollama container: `icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6`
- Podman or Docker runtime
- Streamlit chat on TCP port `8505`
- Ollama API on TCP port `11434`
- Persistent storage under `~/ollama-project/models`
- Streaming responses from the first generated token
- CPU thread count controlled by `OLLAMA_NUM_THREADS` in `.env`

## Installation

```bash
bash setup_environment.sh
cd ~/ollama-project
source venv/bin/activate
./scripts/ollama_manager.sh start
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/streamlit_manager.sh start
```

Open:

```text
http://<server-ip>:8505
```

The Ollama API is exposed at:

```text
http://<server-ip>:11434/api
```

## CPU thread configuration

Edit `~/ollama-project/.env`:

```bash
OLLAMA_NUM_THREADS=16
```

This value is included as Ollama's `options.num_thread` parameter in every generation request made by the Streamlit application and by `scripts/thread_test.sh`. This is the setting that controls the number of CPU inference worker threads for one request.

After changing it, restart Streamlit:

```bash
./scripts/streamlit_manager.sh restart
```

The Ollama container does not need recreation merely for `OLLAMA_NUM_THREADS`, because this project applies the value at request time. Recreate it after changing container environment, port, volume, CPU quota, or CPU affinity settings:

```bash
./scripts/ollama_manager.sh recreate
```

Check CPU visibility:

```bash
./scripts/ollama_manager.sh cpu-info
```

Run a sustained inference test while watching `top`, `htop`, or `nmon`:

```bash
./scripts/thread_test.sh gemma3:4b-it-qat
```

## Important distinction

`OLLAMA_NUM_THREADS` controls worker threads used by a single model inference request. `OLLAMA_NUM_PARALLEL` controls how many requests one loaded model can process concurrently. Increasing `OLLAMA_NUM_PARALLEL` does not make one response use more CPU threads and increases memory requirements.

## Main configuration

```bash
CONTAINER_RUNTIME=podman
CONTAINER_NAME=ollama-ppc64le
OLLAMA_IMAGE=icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6
OLLAMA_HOST_BIND=0.0.0.0
OLLAMA_API_HOST=127.0.0.1
OLLAMA_PORT=11434
STREAMLIT_HOST=0.0.0.0
STREAMLIT_PORT=8505
OLLAMA_CONTEXT_LENGTH=16384
OLLAMA_NUM_THREADS=16
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_MAX_QUEUE=64
OLLAMA_CONTAINER_CPUS=
OLLAMA_CPUSET_CPUS=
```

Leave `OLLAMA_CONTAINER_CPUS` and `OLLAMA_CPUSET_CPUS` empty unless you intentionally want to restrict the container. A CPU quota or CPU set smaller than `OLLAMA_NUM_THREADS` prevents Ollama from using the requested thread count effectively.

## Management commands

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh stop
./scripts/ollama_manager.sh restart
./scripts/ollama_manager.sh recreate
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh logs
./scripts/ollama_manager.sh cpu-info

./scripts/pull_model.sh <model>
./scripts/list_models.sh
./scripts/delete_model.sh <model>

./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh stop
./scripts/streamlit_manager.sh restart
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

## External API clients

A client that calls Ollama directly must also include `num_thread` in `options`; server environment variables do not globally replace the per-request Ollama parameter:

```json
{
  "model": "gemma3:4b-it-qat",
  "prompt": "Explain IBM Power SMT.",
  "stream": true,
  "options": {
    "num_thread": 16,
    "num_ctx": 16384
  }
}
```

Use a trusted network, host firewall, or authenticated reverse proxy because the native Ollama API does not provide application-level authentication.
