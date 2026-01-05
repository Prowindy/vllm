# Quick Start: vLLM Router Integration

## Installation (One-Time Setup)

Since vLLM is already installed in your environment, you only need to build the router:

```bash
# Activate your environment
source ~/uv_env/vllm/bin/activate

# Build router (one command, no internet needed)
python /home/congc/gitrepos/vllm/build_router.py
```

That's it! The router will be built automatically using cargo.

## Testing Localhost Mode

**Start vLLM with router:**
```bash
source ~/uv_env/vllm/bin/activate

vllm serve Qwen/Qwen2.5-0.5B-Instruct \
    --enable-router-as-api-server \
    --port 8000
```

**Expected output:**
```
Starting vLLM in router mode...
Starting gRPC server on 127.0.0.1:50051
gRPC server started successfully
Starting router: /home/congc/gitrepos/vllm/router/target/release/vllm-router --worker-urls http://127.0.0.1:50051 --host 0.0.0.0 --port 8000 --policy cache_aware
Router started successfully on http://0.0.0.0:8000
```

**Test the API (in another terminal):**
```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "prompt": "Once upon a time",
    "max_tokens": 50
  }'
```

**Expected response:**
```json
{
  "id": "...",
  "object": "text_completion",
  "created": 1735437600,
  "model": "Qwen/Qwen2.5-0.5B-Instruct",
  "choices": [
    {
      "text": " in a land far, far away...",
      "index": 0,
      "finish_reason": "length"
    }
  ],
  "usage": {
    "prompt_tokens": 5,
    "completion_tokens": 50,
    "total_tokens": 55
  }
}
```

## Architecture

```
vllm serve --enable-router-as-api-server
    │
    ├─→ gRPC Server (127.0.0.1:50051)
    │   └─→ vLLM AsyncLLM Engine
    │
    └─→ Router (0.0.0.0:8000)
        └─→ HTTP API Server (Rust)
             │
             └─→ Calls gRPC → vLLM Engine
```

## Troubleshooting

**Router binary not found:**
```bash
python /home/congc/gitrepos/vllm/build_router.py
```

**Check if router was built:**
```bash
ls -lh /home/congc/gitrepos/vllm/router/target/release/vllm-router
# Should show: -rwxr-xr-x ... 27M ... vllm-router
```

**Check vLLM installation:**
```bash
source ~/uv_env/vllm/bin/activate
vllm --version
# Should show: 0.11.2.dev449+...
```

## Stopping the Server

Press `Ctrl+C` in the terminal where vLLM is running. Both processes (gRPC and Router) will shut down gracefully.

## What's Next?

- See `ROUTER_INTEGRATION.md` for multi-node mode
- See `IMPLEMENTATION_SUMMARY.md` for technical details
