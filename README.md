# Ollama Testing Environment for IBM Power

This project deploys an Ollama container on IBM Power / `ppc64le` and provides a Streamlit chat interface for model testing, streaming responses, and lightweight performance measurements.

Default container image:

```text
icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6
```

## Features

- Ollama container lifecycle management with Podman or Docker
- External Ollama API binding on `0.0.0.0:11434`
- Persistent model storage under `~/ollama-project/models`
- SELinux-safe Podman volume mount using `:Z`
- In-container Ollama CLI model operations
- Streamlit chat interface on `0.0.0.0:8505`
- Streaming chat responses from the first generated token
- Max output token and context window controls up to `16384`
- Background Streamlit process management

## Project layout

```text
ollama_p11_public/
├── docker-compose.yml
├── .env.example
├── README.md
├── DEPLOYMENT_GUIDE.md
├── QUICK_REFERENCE.md
├── requirements.txt
├── setup_environment.sh
├── .streamlit/
│   └── config.toml
├── scripts/
│   ├── ollama_manager.sh
│   ├── streamlit_manager.sh
│   ├── healthcheck.sh
│   ├── pull_model.sh
│   ├── create_model.sh
│   ├── delete_model.sh
│   └── list_models.sh
├── streamlit/
│   ├── ollama_chat.py
│   ├── config.yaml
│   └── requirements.txt
└── templates/
    └── Modelfile.example
```

`setup_environment.sh` installs the operational copy under:

```text
~/ollama-project
```

## Quick start

```bash
bash setup_environment.sh
cd ~/ollama-project
source venv/bin/activate
./scripts/ollama_manager.sh start
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/streamlit_manager.sh start
```

Open the chat interface:

```text
http://<server-ip>:8505
```

The Ollama API is exposed externally at:

```text
http://<server-ip>:11434/api
```

## Runtime defaults

| Component | Default |
|---|---:|
| Project directory | `~/ollama-project` |
| Container runtime | `podman` if available, otherwise `docker` |
| Container name | `ollama-ppc64le` |
| Ollama image | `icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6` |
| Ollama bind address | `0.0.0.0` |
| Ollama port | `11434` |
| Local API host used by Streamlit | `127.0.0.1` |
| Streamlit bind address | `0.0.0.0` |
| Streamlit port | `8505` |
| Model storage | `~/ollama-project/models` |
| Max output tokens | `16384` |
| Context window tokens | `16384` |

## Main scripts

### Ollama container

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh stop
./scripts/ollama_manager.sh restart
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh logs
./scripts/ollama_manager.sh shell
./scripts/ollama_manager.sh rm
./scripts/ollama_manager.sh pull-image
```

### Model lifecycle

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/custom.Modelfile
./scripts/delete_model.sh granite-custom
```

The model scripts execute the Ollama CLI inside the running container. Example:

```bash
podman exec -it ollama-ppc64le ollama pull gemma3:4b-it-qat
```

### Streamlit service

```bash
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh stop
./scripts/streamlit_manager.sh restart
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

## Configuration files

### `~/ollama-project/.env`

```bash
CONTAINER_RUNTIME=podman
CONTAINER_NAME=ollama-ppc64le
OLLAMA_IMAGE=icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6
OLLAMA_HOST_BIND=0.0.0.0
OLLAMA_API_HOST=127.0.0.1
OLLAMA_PORT=11434
STREAMLIT_HOST=0.0.0.0
STREAMLIT_PORT=8505
PROJECT_DIR=${HOME}/ollama-project
OLLAMA_MODELS_DIR=${HOME}/ollama-project/models
OLLAMA_KEEP_ALIVE=10m
OLLAMA_ORIGINS=*
HTTPS_PROXY=
NO_PROXY=127.0.0.1,localhost
```

### `~/ollama-project/streamlit/config.yaml`

```yaml
api_scheme: http
api_host: 127.0.0.1
ollama_bind_host: 0.0.0.0
container_port: 11434
streamlit_host: 0.0.0.0
streamlit_port: 8505
default_temperature: 0.7
default_num_predict: 16384
default_num_ctx: 16384
default_keep_alive: 10m
```

`api_host` is the address used by the local Streamlit process to call Ollama. `ollama_bind_host` and `OLLAMA_HOST_BIND` control the external container port binding.

## Validation

```bash
cd ~/ollama-project
./scripts/ollama_manager.sh start
./scripts/healthcheck.sh
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh status
```

From another server on the network:

```bash
curl http://<server-ip>:11434/api/tags
```

## Security note

Binding Ollama to `0.0.0.0` makes the API reachable from other machines that can access the server and port. Use firewall rules, network segmentation, or a reverse proxy if the server is on a shared or untrusted network.
