# Deployment Guide: Ollama on IBM Power

## 1. Overview

This project deploys Ollama as a persistent containerized service on IBM Power (`ppc64le`) and provides a Streamlit UI that can stay running in the background on port `8505`.

The runtime model now follows your validated host workflow:

- keep the Ollama service container running
- manage models from inside that container with `ollama pull`, `ollama create`, `ollama rm`, and `ollama list`
- expose the Streamlit chat UI separately as a long-running background process

Ollama exposes a local API at `http://localhost:11434/api`, while Streamlit is configured to run as a headless server with a configurable port. citeturn793305search2turn323234search0turn323234search1

## 2. Host prerequisites

- IBM Power system running Linux with `ppc64le`
- Podman preferred, Docker supported
- Python 3.9+
- Internet access to pull models when needed
- Enough disk capacity for local model storage
- SELinux-aware bind mounts when using Podman on enforcing systems, which is why the project uses `:Z` on the model volume mount

## 3. Source layout and install layout

The GitHub repo contains the source tree. The setup script creates or refreshes the runtime tree under:

```text
~/ollama-project
```

That working directory contains:

- `scripts/`
- `streamlit/`
- `.streamlit/`
- `models/`
- `logs/`
- `modelfiles/`
- `venv/`
- `.env`

The current repo already documents the `scripts`, `streamlit`, and `templates` structure and uses `setup_environment.sh` from the repository root. citeturn232924view0turn532828view0

## 4. Installation

Run:

```bash
bash setup_environment.sh
```

This script now does the following:

- creates `~/ollama-project`
- creates a Python virtual environment
- installs Streamlit dependencies with your Fury wheel index override
- copies scripts, templates, docs, and app files into the runtime directory
- writes `.env`
- writes `streamlit/config.yaml`
- writes `.streamlit/config.toml`
- pulls the IBM Power Ollama image

Your Fury option is now part of the install flow. citeturn532828view0

## 5. Start the Ollama container

```bash
cd ~/ollama-project
./scripts/ollama_manager.sh start
```

Useful checks:

```bash
./scripts/ollama_manager.sh status
./scripts/healthcheck.sh
```

The container uses:

- image: `icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6`
- host bind: `127.0.0.1:11434` by default
- volume: `~/ollama-project/models:/root/.ollama:Z`

## 6. Pull models the same way you validated manually

You confirmed this syntax works on your system:

```bash
podman exec -it ollama-ppc64le ollama pull model_name
```

The project now wraps that exact operational pattern in:

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
```

That aligns with Ollama’s CLI model workflow. citeturn101224search0

## 7. List, create, and delete models

### List

```bash
./scripts/list_models.sh
```

### Create from Modelfile

Copy and edit the template:

```bash
cp templates/Modelfile.example ~/ollama-project/modelfiles/my-granite.Modelfile
vi ~/ollama-project/modelfiles/my-granite.Modelfile
```

Create the model:

```bash
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/my-granite.Modelfile
```

Ollama’s Modelfile workflow is based on `ollama create <name> -f <Modelfile>`. citeturn101224search8

### Delete

```bash
./scripts/delete_model.sh granite-custom
```

## 8. Start Streamlit as a background service

This project now treats Streamlit as a persistent background service rather than an interactive foreground command.

Start it:

```bash
source ~/ollama-project/venv/bin/activate
cd ~/ollama-project
./scripts/streamlit_manager.sh start
```

Check it:

```bash
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

Stop it:

```bash
./scripts/streamlit_manager.sh stop
```

The Streamlit service uses:

- address: `0.0.0.0`
- port: `8505`
- headless mode: enabled
- log file: `~/ollama-project/logs/streamlit.log`
- pid file: `~/ollama-project/logs/streamlit.pid`

Streamlit documents both `config.toml` and command-line server settings for this style of deployment. citeturn323234search0turn323234search1turn323234search6

## 9. Access model testing UI

Open:

```text
http://<server-ip>:8505
```

The UI talks to the local Ollama API on `127.0.0.1:11434` and keeps model execution local to the server.

## 10. Operational commands

### Ollama container

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh stop
./scripts/ollama_manager.sh restart
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh logs
./scripts/ollama_manager.sh shell
./scripts/ollama_manager.sh rm
```

### Streamlit

```bash
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh stop
./scripts/streamlit_manager.sh restart
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

### Models

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
./scripts/list_models.sh
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/my.Modelfile
./scripts/delete_model.sh granite-custom
```

## 11. Common issues

### Permission denied in `/root/.ollama`

This usually means the host model directory is not writable or the bind mount is missing an SELinux relabel.

This project uses:

```text
-v ~/ollama-project/models:/root/.ollama:Z
```

If needed:

```bash
mkdir -p ~/ollama-project/models
chmod 700 ~/ollama-project/models
chmod -R u+rwX ~/ollama-project/models
```

### Container is up but model pulls fail

Check:

- outbound DNS
- proxy variables
- free disk space
- container logs

### Streamlit does not stay running

Check:

```bash
./scripts/streamlit_manager.sh logs
./scripts/streamlit_manager.sh status
```

Also confirm the virtual environment exists and `streamlit` is installed in `~/ollama-project/venv`.

### Streamlit page not reachable remotely

Confirm:

- `8505/tcp` is open in the host firewall
- Streamlit is bound to `0.0.0.0`
- the process is running according to `streamlit_manager.sh status`

## 12. Recommended first-day validation

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
