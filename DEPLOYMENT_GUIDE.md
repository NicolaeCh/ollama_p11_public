# Deployment Guide — Ollama on IBM Power

## 1. Platform requirements

- IBM Power LPAR running RHEL 10 or another supported ppc64le Linux distribution
- Podman recommended
- Python 3 and the Python venv package
- At least 16 logical CPUs visible to the LPAR when `OLLAMA_NUM_THREADS=16`
- Sufficient RAM for the selected model and context window

Verify CPU entitlement and visibility before deployment:

```bash
nproc
lscpu
```

On PowerVM, also verify the LPAR has enough virtual processors and entitled/shared processor capacity. A request for 16 software threads cannot overcome a low processor entitlement or a container CPU restriction.

## 2. Install

```bash
bash setup_environment.sh
cd ~/ollama-project
source venv/bin/activate
```

Python packages are installed with the ppc64le binary repository:

```bash
pip install -r streamlit/requirements.txt \
  --prefer-binary \
  --extra-index-url=https://repo.fury.io/mgiessing
```

## 3. Configure `.env`

The principal CPU setting is:

```bash
OLLAMA_NUM_THREADS=16
```

Recommended baseline:

```bash
OLLAMA_CONTEXT_LENGTH=16384
OLLAMA_NUM_THREADS=16
OLLAMA_NUM_PARALLEL=1
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_MAX_QUEUE=64
OLLAMA_CONTAINER_CPUS=
OLLAMA_CPUSET_CPUS=
```

`OLLAMA_NUM_THREADS` is read by the Streamlit process and supplied to Ollama as `options.num_thread` on every `/api/chat` request. The test script supplies the same value to `/api/generate`.

Do not confuse this with `OLLAMA_NUM_PARALLEL`. Parallel request slots provide concurrency, not additional threads for one generation, and multiply context-memory requirements.

## 4. Start Ollama

```bash
./scripts/ollama_manager.sh start
./scripts/ollama_manager.sh status
./scripts/ollama_manager.sh cpu-info
```

The expected ports are:

```text
0.0.0.0:11434 -> Ollama API
0.0.0.0:8505  -> Streamlit UI
```

## 5. Pull a model

```bash
./scripts/pull_model.sh gemma3:4b-it-qat
```

Equivalent Podman command:

```bash
podman exec -it ollama-ppc64le ollama pull gemma3:4b-it-qat
```

## 6. Start Streamlit

```bash
./scripts/streamlit_manager.sh start
./scripts/streamlit_manager.sh status
```

Open:

```text
http://<server-ip>:8505
```

The thread count displayed in the sidebar is read-only and comes from `.env`. Restart Streamlit after editing the value:

```bash
./scripts/streamlit_manager.sh restart
```

## 7. Verify multithreaded inference

Terminal 1:

```bash
nmon
```

Terminal 2:

```bash
./scripts/thread_test.sh gemma3:4b-it-qat \
  "Write a detailed technical explanation of PowerVM processor virtualization."
```

Terminal 3:

```bash
podman logs -f ollama-ppc64le
```

The test sends:

```json
"options": {
  "num_thread": 16,
  "num_ctx": 16384,
  "num_predict": 512
}
```

A short prompt, model loading, token sampling, or the final part of generation may not keep all threads busy continuously. Judge utilization during a sustained prompt-evaluation or generation interval, not only from a single instantaneous `top` sample.

## 8. CPU restrictions

Check the container view:

```bash
./scripts/ollama_manager.sh cpu-info
```

Optional restriction variables:

```bash
OLLAMA_CONTAINER_CPUS=16
OLLAMA_CPUSET_CPUS=0-15
```

They are empty by default. Setting them constrains the container; they do not increase the LPAR's available CPU capacity. After changing either value:

```bash
./scripts/ollama_manager.sh recreate
```

## 9. Direct API clients

Any application bypassing Streamlit must explicitly send `options.num_thread`:

```bash
curl http://<server-ip>:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{
    "model":"gemma3:4b-it-qat",
    "prompt":"Explain simultaneous multithreading on IBM Power.",
    "stream":false,
    "options":{"num_thread":16,"num_ctx":16384,"num_predict":512}
  }'
```

## 10. Troubleshooting one-CPU utilization

1. Confirm the actual request contains `num_thread`.
2. Run `./scripts/ollama_manager.sh cpu-info`.
3. Check `nproc` on the host and inside the container.
4. Ensure `OLLAMA_CONTAINER_CPUS` and `OLLAMA_CPUSET_CPUS` are empty or permit at least 16 logical CPUs.
5. Check PowerVM virtual processors and entitlement.
6. Use a sufficiently long generation test.
7. Recreate the container after changing container CPU controls.
8. Restart Streamlit after changing `OLLAMA_NUM_THREADS`.

## 11. Firewall

```bash
sudo firewall-cmd --add-port=11434/tcp --permanent
sudo firewall-cmd --add-port=8505/tcp --permanent
sudo firewall-cmd --reload
```

Restrict these ports to trusted subnets whenever possible.
