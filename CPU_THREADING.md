# CPU Threading on IBM Power

The project separates three different controls:

1. `OLLAMA_NUM_THREADS`: inference threads requested in each Ollama API call made by the supplied applications.
2. `OLLAMA_CONTAINER_CPUS`: Compose CPU quota available to the Ollama container.
3. `OLLAMA_NUM_PARALLEL`: number of requests Ollama may process concurrently for one model.

For a 16-thread deployment:

```dotenv
OLLAMA_NUM_THREADS=16
OLLAMA_CONTAINER_CPUS=16
OLLAMA_NUM_PARALLEL=1
```

The Streamlit chat sends:

```json
"options": {
  "num_thread": 16,
  "num_ctx": 16384,
  "num_predict": 512
}
```

Changing only `OLLAMA_NUM_PARALLEL` does not increase the CPU threads used for one answer.

## IBM Power interpretation

Linux logical CPUs are SMT hardware threads, not necessarily physical cores. With SMT8, 16 logical CPUs can represent two physical cores. Check:

```bash
nproc
lscpu
ppc64_cpu --smt
lparstat -i
lparstat 1
```

The LPAR must have sufficient virtual processors and entitlement. A container cannot use CPU capacity that is not available to the RHEL LPAR.

## Verification sequence

```bash
./scripts/ollama_manager.sh config
./scripts/ollama_manager.sh recreate
./scripts/streamlit_manager.sh restart
./scripts/ollama_manager.sh verify
./scripts/thread_test.sh gemma3:4b-it-qat
```

Monitor with `nmon`, `top`, or `podman stats` during a long generation. Very short prompts may not sustain enough work to make all configured threads visible in a sampling tool.
