# Ollama Testing Environment for IBM Power

This project is the Ollama-based equivalent of your `vllm_p11_public` flow, adapted for IBM Power and the IBM container image:

- `icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6`

It keeps the same practical pattern as your vLLM project:

- local project under `~/ollama-project`
- helper scripts for deployment and operations
- Streamlit UI for model testing
- persistent host-side model storage
- lightweight documentation for daily operations

The repository structure on GitHub reflects the source project, and `setup_environment.sh` installs or refreshes the working copy under `~/ollama-project`. The current repo already uses that layout and includes your additional Fury wheel index for Python dependencies. citeturn232924view0turn532828view0

## What changed in this revision

This update aligns the project with the changes you made in your repo and host workflow:

- `setup_environment.sh` uses your Fury option: `--prefer-binary --extra-index-url=https://repo.fury.io/mgiessing`. citeturn532828view0
- Ollama container storage uses the SELinux-safe volume mount suffix `:Z`, which is the correct Podman pattern on SELinux-enabled systems. citeturn532828view0turn323234search0
- Model download is now based on container CLI execution, matching your working syntax: `podman exec -it ollama-ppc64le ollama pull <model>`. This is consistent with Ollama’s CLI model workflow, including `ollama pull` and `ollama create`. citeturn101224search0turn101224search8
- Streamlit now defaults to port `8505`.
- Streamlit can now run permanently in the background through `scripts/streamlit_manager.sh`, using headless server mode, which Streamlit supports through command-line flags and configuration. citeturn323234search0turn323234search1turn323234search6

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

## Quick start

```bash
bash setup_environment.sh
cd ~/ollama-project
source venv/bin/activate
./scripts/ollama_manager.sh start
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/streamlit_manager.sh start
```

Then open:

```text
http://<server-ip>:8505
```

## Main operating model

### 1. Start the Ollama service container

```bash
cd ~/ollama-project
./scripts/ollama_manager.sh start
```

### 2. Pull a model inside the running container

This project now uses the same operational syntax you validated manually:

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
```

Equivalent underlying command:

```bash
podman exec -it ollama-ppc64le ollama pull gemma3:4b-it-qat
```

### 3. Start Streamlit in background mode

```bash
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

## Script summary

### Container lifecycle

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh stop
./scripts/ollama_manager.sh restart
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh logs
./scripts/ollama_manager.sh shell
./scripts/ollama_manager.sh rm
```

### Model lifecycle

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/my.Modelfile
./scripts/delete_model.sh granite-custom
```

### Streamlit lifecycle

```bash
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh stop
./scripts/streamlit_manager.sh restart
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

## Notes for IBM Power and Podman

- Ollama’s API is normally exposed on `http://localhost:11434/api`. citeturn793305search2
- Ollama model pulls are supported both by API and CLI, but this project now prefers the in-container CLI for pull/create/delete/list because that matches your validated runtime behavior on Power. citeturn793305search1turn101224search0turn101224search8
- Streamlit’s server port and headless mode are controlled through command-line flags or `config.toml`; this project uses both so it behaves predictably in unattended operation. citeturn323234search0turn323234search1

## Suggested first validation sequence

```bash
bash setup_environment.sh
cd ~/ollama-project
source venv/bin/activate
./scripts/ollama_manager.sh start
./scripts/healthcheck.sh
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh status
```

## Current defaults

- Ollama API bind: `127.0.0.1:11434`
- Streamlit bind: `0.0.0.0:8505`
- Container name: `ollama-ppc64le`
- Project root: `~/ollama-project`
- Model storage: `~/ollama-project/models`
