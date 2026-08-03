# Ollama on IBM Power (ppc64le)

Containerized Ollama deployment for RHEL 10 on IBM Power, with a persistent Streamlit chat UI, configurable CPU inference threads, and connectivity to an n8n backend network.

## Runtime architecture

The Ollama container is created exclusively through `docker-compose.yml`. `scripts/ollama_manager.sh` loads the project `.env` and invokes the available Compose provider (`podman compose`, `podman-compose`, `docker compose`, or `docker-compose`). It does not use a separate `podman run` configuration.

The container joins both networks:

- `ollama-net-local`, created by this project.
- `n8n-ppc64le_n8n_net`, an external network that must already exist.

Ollama is published on `0.0.0.0:11434`. Streamlit runs as a persistent host process on `0.0.0.0:8505`.

## Installation

```bash
cd ~/ollama-project
./setup_environment.sh
```

The installer creates `.env` from `.env.example`, creates a Python virtual environment, installs the Streamlit dependencies using the configured Fury index, and pulls the ppc64le Ollama image.

Ensure the n8n network exists before starting Ollama:

```bash
podman network exists n8n-ppc64le_n8n_net || \
  podman network create n8n-ppc64le_n8n_net
```

Start and verify:

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh verify
./scripts/streamlit_manager.sh start
```

Open:

```text
http://SERVER_IP:8505
```

## CPU thread configuration

Set both values in `.env`:

```dotenv
OLLAMA_NUM_THREADS=16
OLLAMA_CONTAINER_CPUS=16
```

`OLLAMA_NUM_THREADS` is read by the supplied Streamlit application and sent in every `/api/chat` request as:

```json
{"options": {"num_thread": 16}}
```

`OLLAMA_CONTAINER_CPUS` defines the Compose CPU quota. It must be equal to or greater than `OLLAMA_NUM_THREADS`.

`OLLAMA_NUM_PARALLEL` controls simultaneous requests; it does not control the inference threads used by one generation.

After changing `.env`:

```bash
./scripts/ollama_manager.sh recreate
./scripts/streamlit_manager.sh restart
./scripts/ollama_manager.sh verify
```

Test a model with the configured thread count:

```bash
./scripts/thread_test.sh gemma3:4b-it-qat
```

External clients, including n8n, must send `options.num_thread` in their Ollama request. Ollama does not expose a documented global server environment variable that forces `num_thread` for every client.

## Model management

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/delete_model.sh gemma3:4b-it-qat
```

The pull script executes the tested container command:

```bash
podman exec -it ollama-ppc64le ollama pull gemma3:4b-it-qat
```

## Management commands

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh stop
./scripts/ollama_manager.sh restart
./scripts/ollama_manager.sh recreate
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh logs
./scripts/ollama_manager.sh config
./scripts/ollama_manager.sh cpu-info
./scripts/ollama_manager.sh verify
```

`config` prints the resolved Compose configuration. `verify` checks the Compose file, container state, both network attachments, API availability, host CPU visibility, container CPU visibility, and configured thread values.

## n8n access

Because both containers share `n8n-ppc64le_n8n_net`, n8n can use:

```text
http://ollama-ppc64le:11434
```

Example request body:

```json
{
  "model": "gemma3:4b-it-qat",
  "messages": [{"role": "user", "content": "Explain IBM Power SMT."}],
  "stream": false,
  "options": {
    "num_thread": 16,
    "num_ctx": 16384,
    "num_predict": 1024
  }
}
```
