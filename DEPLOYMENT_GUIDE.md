# Deployment Guide

This guide describes a clean deployment of the Ollama testing environment on IBM Power Linux.

## 1. Requirements

- IBM Power server with `ppc64le` Linux
- Podman or Docker
- Python 3
- Network access to pull the container image
- Optional: firewall access for ports `11434` and `8505`

Default image:

```text
icr.io/ppc64le-oss/ollama-ppc64le:v0.17.6
```

## 2. Install the project

From the repository directory:

```bash
bash setup_environment.sh
```

The installer creates or refreshes:

```text
~/ollama-project
```

It also creates:

```text
~/ollama-project/venv
~/ollama-project/models
~/ollama-project/logs
~/ollama-project/modelfiles
```

Python dependencies are installed with:

```bash
pip install -r streamlit/requirements.txt --prefer-binary --extra-index-url=https://repo.fury.io/mgiessing
```

## 3. Start the Ollama container

```bash
cd ~/ollama-project
./scripts/ollama_manager.sh start
```

Check status and logs:

```bash
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh logs
```

The container publishes Ollama as:

```text
0.0.0.0:11434 -> container:11434
```

Inside the container, Ollama is configured with:

```text
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_MODELS=/root/.ollama/models
```

The host model directory is mounted as:

```text
~/ollama-project/models:/root/.ollama:Z
```

## 4. Validate the Ollama API

From the IBM Power host:

```bash
./scripts/healthcheck.sh
```

From another server:

```bash
curl http://<server-ip>:11434/api/tags
```

If remote access fails, check the host firewall and any network ACLs between the client and the Power server.

## 5. Pull a model

Model operations run the Ollama CLI inside the container.

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
```

Equivalent command:

```bash
podman exec -it ollama-ppc64le ollama pull gemma3:4b-it-qat
```

List local models:

```bash
./scripts/list_models.sh
```

Delete a model:

```bash
./scripts/delete_model.sh <model-name>
```

## 6. Create a custom model from a Modelfile

Create a Modelfile under:

```text
~/ollama-project/modelfiles
```

Example:

```bash
cp ~/ollama-project/templates/Modelfile.example ~/ollama-project/modelfiles/custom.Modelfile
vi ~/ollama-project/modelfiles/custom.Modelfile
./scripts/create_model.sh granite-custom ~/ollama-project/modelfiles/custom.Modelfile
```

## 7. Start Streamlit in background mode

```bash
source ~/ollama-project/venv/bin/activate
cd ~/ollama-project
./scripts/streamlit_manager.sh start
```

Check status and logs:

```bash
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

Open:

```text
http://<server-ip>:8505
```

The UI uses streaming Ollama chat requests. Assistant responses are displayed while tokens are generated, without waiting for the full response.

## 8. Token settings

The Streamlit interface exposes:

```text
Max output tokens: 32 - 16384
Context window tokens: 2048 - 16384
```

The default configuration is:

```yaml
default_num_predict: 16384
default_num_ctx: 16384
```

Some models may have a lower practical context window or may consume more memory with high values. Reduce the values in the sidebar if generation is slow or memory constrained.

## 9. Recreate the container after binding or volume changes

Container port bindings and volume mounts are fixed when the container is created. After editing `.env` values such as `OLLAMA_HOST_BIND`, `OLLAMA_PORT`, or `OLLAMA_MODELS_DIR`, recreate the container:

```bash
cd ~/ollama-project
./scripts/ollama_manager.sh rm
./scripts/ollama_manager.sh start
```

## 10. Firewall example

On systems using `firewalld`:

```bash
sudo firewall-cmd --add-port=11434/tcp --permanent
sudo firewall-cmd --add-port=8505/tcp --permanent
sudo firewall-cmd --reload
```

Only open these ports on trusted networks.

## 11. Troubleshooting

### API is not reachable from another server

Check the container binding:

```bash
podman ps --format "table {{.Names}}\t{{.Ports}}"
```

Expected binding:

```text
0.0.0.0:11434->11434/tcp
```

Check firewall rules:

```bash
sudo firewall-cmd --list-ports
```

### Streamlit is not reachable

Check the background process:

```bash
./scripts/streamlit_manager.sh status
./scripts/streamlit_manager.sh logs
```

Expected binding:

```text
0.0.0.0:8505
```

### Permission denied on `/root/.ollama`

Check the host models directory:

```bash
ls -ld ~/ollama-project/models
chmod 700 ~/ollama-project/models
```

The container uses the SELinux relabel suffix `:Z` for the bind mount.

### Model pull fails

Confirm the container is running:

```bash
./scripts/ollama_manager.sh status
```

Then retry:

```bash
./scripts/pull_model.sh <model-name>
```
