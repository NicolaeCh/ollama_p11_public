# CPU Threading on IBM Power

The `ollama-server` process appearing near 100% CPU in `top` or `nmon` means approximately one logical CPU is busy. The original project configured token and context parameters but did not send Ollama's `num_thread` inference option, so the application relied entirely on Ollama's automatic CPU selection.

This project uses:

```bash
OLLAMA_NUM_THREADS=16
```

The Streamlit application reads this variable from `.env` and sends:

```json
"options": {
  "num_thread": 16
}
```

for every generation. The value is also used by `scripts/thread_test.sh`.

The server variables `OLLAMA_NUM_PARALLEL`, `OLLAMA_MAX_LOADED_MODELS`, and `OLLAMA_MAX_QUEUE` have different purposes. They manage request concurrency, model residency, and queue depth. They do not determine the CPU worker count for one response.

On IBM Power, check all four layers:

1. LPAR virtual processors and processing entitlement.
2. Linux online CPUs (`nproc`, `lscpu`).
3. Podman CPU quota and affinity.
4. Ollama request option `num_thread`.

Use:

```bash
./scripts/ollama_manager.sh cpu-info
./scripts/thread_test.sh <model>
```

A model must be actively evaluating a sufficiently long prompt or generating enough tokens before CPU utilization can be assessed reliably.
