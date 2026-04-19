# Quick Reference

## Setup

```bash
bash setup_environment.sh
source ~/ollama-project/venv/bin/activate
cd ~/ollama-project
```

## Ollama container lifecycle

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh stop
./scripts/ollama_manager.sh restart
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh logs
./scripts/ollama_manager.sh shell
./scripts/ollama_manager.sh rm
```

## Model operations

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/my.Modelfile
./scripts/delete_model.sh granite-custom
```

## Health checks

```bash
./scripts/healthcheck.sh
curl http://127.0.0.1:11434/api/tags
curl http://127.0.0.1:11434/api/ps
```

## Streamlit background service

```bash
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh stop
./scripts/streamlit_manager.sh restart
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

## Streamlit UI URL

```text
http://<server-ip>:8505
```

## Compose

```bash
cp .env.example .env
podman-compose up -d
# or
# docker compose up -d
```
