# Quick Reference

## Install

```bash
bash setup_environment.sh
cd ~/ollama-project
source venv/bin/activate
```

## Start services

```bash
./scripts/ollama_manager.sh start
./scripts/streamlit_manager.sh start
```

## Stop services

```bash
./scripts/streamlit_manager.sh stop
./scripts/ollama_manager.sh stop
```

## Status

```bash
./scripts/ollama_manager.sh status
./scripts/streamlit_manager.sh status
```

## Logs

```bash
./scripts/ollama_manager.sh logs
./scripts/streamlit_manager.sh logs
```

## API and UI URLs

```text
Ollama API:  http://<server-ip>:11434/api
Streamlit:   http://<server-ip>:8505
```

## Pull a model

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
```

Underlying command:

```bash
podman exec -it ollama-ppc64le ollama pull gemma3:4b-it-qat
```

## List models

```bash
./scripts/list_models.sh
```

## Delete a model

```bash
./scripts/delete_model.sh <model-name>
```

## Create a model from a Modelfile

```bash
./scripts/create_model.sh <new-model-name> ~/ollama-project/modelfiles/custom.Modelfile
```

## Health check

```bash
./scripts/healthcheck.sh
curl http://<server-ip>:11434/api/tags
```

## Default ports

| Service | Bind | Port |
|---|---:|---:|
| Ollama API | `0.0.0.0` | `11434` |
| Streamlit UI | `0.0.0.0` | `8505` |

## Default token controls

```text
Max output tokens: 16384
Context window tokens: 16384
```

## Recreate container

Use this after changing `.env` port binding or volume settings:

```bash
./scripts/ollama_manager.sh rm
./scripts/ollama_manager.sh start
```

## Firewall example

```bash
sudo firewall-cmd --add-port=11434/tcp --permanent
sudo firewall-cmd --add-port=8505/tcp --permanent
sudo firewall-cmd --reload
```
