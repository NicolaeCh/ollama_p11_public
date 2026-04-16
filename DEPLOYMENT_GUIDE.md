# Deployment Guide: Ollama on IBM Power

## 1. Overview

This project deploys Ollama as a containerized service on IBM Power (`ppc64le`) and adds a lightweight Streamlit management and testing UI.

### Runtime model

- Container runtime: Podman or Docker
- Container image: `icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6`
- API endpoint: `http://<host>:11434/api`
- Persistent model storage: host-mounted directory

## 2. Host prerequisites

- IBM Power system running Linux with `ppc64le`
- Podman or Docker
- Python 3.9+
- Network access for pulling models from Ollama registries when required
- Sufficient disk for model storage

## 3. Installation

```bash
bash setup_environment.sh
```

That script creates:

- `~/ollama-project`
- `~/ollama-project/models`
- `~/ollama-project/scripts`
- `~/ollama-project/streamlit`
- `~/ollama-project/logs`
- `~/ollama-project/modelfiles`
- `~/ollama-project/venv`

## 4. Start the container

```bash
cd ~/ollama-project
./scripts/ollama_manager.sh start
```

Check status:

```bash
./scripts/ollama_manager.sh status
./scripts/healthcheck.sh
```

## 5. Pull a model

```bash
./scripts/pull_model.sh granite3.3:8b
```

List models:

```bash
./scripts/list_models.sh
```

## 6. Create a custom model from a Modelfile

Copy and edit the template:

```bash
cp templates/Modelfile.example ~/ollama-project/modelfiles/my-granite.Modelfile
vi ~/ollama-project/modelfiles/my-granite.Modelfile
```

Create the model:

```bash
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/my-granite.Modelfile
```

## 7. Launch the Streamlit UI

```bash
source ~/ollama-project/venv/bin/activate
cd ~/ollama-project/streamlit
streamlit run ollama_chat.py --server.port 8501
```

## 8. Network exposure guidance

By default, Ollama should be bound to `127.0.0.1:11434` unless there is a deliberate requirement to expose it.

For a remote Streamlit UI:

- Expose `8501/tcp`
- Keep `11434/tcp` local if possible
- Let Streamlit talk to Ollama locally on the server

## 9. Operations

Restart container:

```bash
./scripts/ollama_manager.sh restart
```

View logs:

```bash
./scripts/ollama_manager.sh logs
```

Open a shell in the container:

```bash
./scripts/ollama_manager.sh shell
```

Stop container:

```bash
./scripts/ollama_manager.sh stop
```

## 10. Cleanup

Delete a model:

```bash
./scripts/delete_model.sh granite3.3:8b
```

Remove the container only:

```bash
./scripts/ollama_manager.sh rm
```

Remove everything manually:

- Container
- Host project directory
- Persistent model cache

## 11. Common issues

### API not reachable

- Verify the container is running
- Confirm the port binding in `config.yaml`
- Check firewall rules
- Run `./scripts/healthcheck.sh`

### Model pull hangs or fails

- Check DNS/proxy configuration
- Prefer `HTTPS_PROXY` instead of `HTTP_PROXY` when proxying outbound model pulls
- Check available disk space

### Permission problems on model storage

- Ensure the runtime user can read/write the host-mounted model directory
- For rootless Podman, confirm UID/GID ownership aligns with the user running the container
