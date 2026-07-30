# Quick Reference

## Set 16 inference threads

```bash
vi ~/ollama-project/.env
OLLAMA_NUM_THREADS=16
./scripts/streamlit_manager.sh restart
```

## Verify CPU visibility

```bash
nproc
./scripts/ollama_manager.sh cpu-info
```

## Start

```bash
./scripts/ollama_manager.sh start
./scripts/streamlit_manager.sh start
```

## Test 16-thread request

```bash
./scripts/thread_test.sh gemma3:4b-it-qat
```

## Recreate after container-setting changes

```bash
./scripts/ollama_manager.sh recreate
```

## URLs

```text
Ollama API: http://<server-ip>:11434/api
Streamlit:  http://<server-ip>:8505
```

## CPU-related variables

```bash
OLLAMA_NUM_THREADS=16       # threads requested per inference
OLLAMA_NUM_PARALLEL=1       # concurrent requests per model
OLLAMA_CONTAINER_CPUS=      # optional CPU quota; empty = unrestricted
OLLAMA_CPUSET_CPUS=         # optional affinity; empty = unrestricted
```

## Direct API requirement

Applications calling Ollama directly must send:

```json
"options": {"num_thread": 16}
```
