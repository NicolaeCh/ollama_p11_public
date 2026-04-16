# Quick Reference

## Setup

```bash
bash setup_environment.sh
source ~/ollama-project/venv/bin/activate
```

## Container lifecycle

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
./scripts/pull_model.sh granite3.3:8b
./scripts/list_models.sh
./scripts/delete_model.sh granite3.3:8b
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/my.Modelfile
```

## Health checks

```bash
./scripts/healthcheck.sh
curl http://127.0.0.1:11434/api/tags
curl http://127.0.0.1:11434/api/ps
```

## Streamlit UI

```bash
cd ~/ollama-project/streamlit
streamlit run ollama_chat.py --server.port 8501
```

## Compose

```bash
cp .env.example .env
podman-compose up -d
# or
# docker compose up -d
```
