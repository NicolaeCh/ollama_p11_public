# Ollama Testing Environment for IBM Power

An IBM Power-focused local LLM testing environment modeled after the structure of `vllm_p11_public`, but rebuilt around an Ollama container runtime using the IBM Power image:

- `icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6`

This project provides:

- One-command setup for Podman or Docker on `ppc64le`
- Persistent Ollama model storage on the host
- Streamlit chat UI for testing local models
- Model pull, create, list, inspect, and delete workflows
- Container lifecycle management scripts
- Health checks and operational logs
- Optional `docker-compose.yml` for teams that prefer compose-based deployment

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
├── scripts/
│   ├── ollama_manager.sh
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
./scripts/pull_model.sh granite3.3:8b
cd streamlit
streamlit run ollama_chat.py --server.port 8501
```

Then open `http://<server-ip>:8501`.

## Main differences vs the vLLM project

This version is designed around Ollama’s local API and model lifecycle:

- No explicit “serve one selected model per container” workflow
- Models are pulled and managed by Ollama itself
- The API base is `http://<host>:11434/api`
- Chat uses `/api/chat`
- Model pulls use `/api/pull`
- Model discovery uses `/api/tags`
- Running models can be checked with `/api/ps`

## Recommended IBM Power usage notes

- Prefer Podman first, Docker second.
- Keep the Ollama model directory on a fast filesystem with plenty of space.
- Bind Ollama to `127.0.0.1` for single-host admin access, or `0.0.0.0` only when you intentionally expose it on the network behind firewall controls.
- For team usage, put a reverse proxy in front of Ollama or expose only the Streamlit UI.

## Suggested first models to validate the environment

Examples you can try after startup:

- `granite3.3:8b`
- `llama3.1:8b`
- `qwen2.5:7b`

Use whichever tags are actually available to your Ollama host.
