# Quick Reference

```bash
cd ~/ollama-project
```

## Start

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh verify
./scripts/streamlit_manager.sh start
```

## CPU configuration

```dotenv
OLLAMA_NUM_THREADS=16
OLLAMA_CONTAINER_CPUS=16
```

Apply:

```bash
./scripts/ollama_manager.sh recreate
./scripts/streamlit_manager.sh restart
```

Test:

```bash
./scripts/thread_test.sh gemma3:4b-it-qat
```

## Compose and network checks

```bash
./scripts/ollama_manager.sh config
podman inspect ollama-ppc64le
podman network inspect ollama-net-local
podman network inspect n8n-ppc64le_n8n_net
```

## Models

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/delete_model.sh gemma3:4b-it-qat
```

## Logs

```bash
./scripts/ollama_manager.sh logs
./scripts/streamlit_manager.sh logs
```

## Endpoints

- External Ollama API: `http://SERVER_IP:11434`
- Streamlit: `http://SERVER_IP:8505`
- From n8n network: `http://ollama-ppc64le:11434`
