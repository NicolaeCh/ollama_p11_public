# Deployment Guide

## 1. Requirements

- IBM Power ppc64le LPAR
- RHEL 10
- Podman and a Compose provider
- Python 3 with `venv`
- An existing external network named `n8n-ppc64le_n8n_net`
- At least as many online logical CPUs as the requested inference thread count

Check the host:

```bash
uname -m
nproc
lscpu
podman --version
podman compose version || podman-compose --version
podman network inspect n8n-ppc64le_n8n_net
```

## 2. Configure

Run:

```bash
cd ~/ollama-project
./setup_environment.sh
```

Review `.env`. The important CPU values are:

```dotenv
OLLAMA_NUM_THREADS=16
OLLAMA_CONTAINER_CPUS=16
```

The CPU quota may be greater than the inference thread value, but must not be lower.

## 3. Start Ollama through Compose

```bash
./scripts/ollama_manager.sh start
```

The manager always uses `docker-compose.yml` with the project `.env`. It performs a preflight check for the external n8n network and validates numeric CPU settings.

Inspect the fully resolved deployment:

```bash
./scripts/ollama_manager.sh config
```

Verify the running deployment:

```bash
./scripts/ollama_manager.sh verify
```

## 4. Pull a model

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
```

## 5. Start Streamlit

```bash
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh status
```

The application derives the project directory from its own file location and reads `.env` from that directory. `.env` values are applied after `streamlit/config.yaml`, so the deployment environment is authoritative.

## 6. Confirm thread use

Run a sustained request:

```bash
./scripts/thread_test.sh gemma3:4b-it-qat
```

In another terminal:

```bash
nmon
```

or:

```bash
podman stats ollama-ppc64le
```

The test sends `options.num_thread` using `OLLAMA_NUM_THREADS` and reports the peak number of Ollama/runner OS tasks observed during generation. The task count includes helper threads and is therefore a diagnostic signal, not an exact inference-thread counter.

## 7. Apply configuration changes

For changes to container settings, networks, image, ports, or CPU quota:

```bash
./scripts/ollama_manager.sh recreate
```

For changes to `OLLAMA_NUM_THREADS`, restart Streamlit so it reloads `.env`:

```bash
./scripts/streamlit_manager.sh restart
```

Using both commands after CPU changes is recommended:

```bash
./scripts/ollama_manager.sh recreate
./scripts/streamlit_manager.sh restart
./scripts/ollama_manager.sh verify
```

## 8. Network behavior

Compose creates `ollama-net-local` and attaches the Ollama container to it. It also attaches the container to the external `n8n-ppc64le_n8n_net` network.

From n8n, use:

```text
http://ollama-ppc64le:11434/api/chat
```

For n8n requests, include the same `options.num_thread` value used by Streamlit.
