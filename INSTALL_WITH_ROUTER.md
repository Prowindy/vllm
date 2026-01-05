# vLLM Router - Quick Installation & Testing

## ✅ One-Command Installation (Using Modified Setup Script)

The setup script has been modified to use your existing vllm directory with all router changes:

```bash
# Run the modified setup script with precompiled mode
VLLM_USE_PRECOMPILED=1 /home/congc/fbsource/fbcode/vllm/fb/scripts/setup_oss_uv.sh
```

**What this does:**
- Uses existing vllm directory at `/home/congc/gitrepos/vllm` (no git clone)
- Keeps all your router implementation changes
- Sets up uv virtual environment at `~/uv_env/vllm`
- Installs PyTorch and CUDA dependencies
- Builds vLLM with `VLLM_BUILD_ROUTER=1` (builds router via cargo)
- Uses `VLLM_USE_PRECOMPILED=1` to skip C++ rebuild

**Expected output:**
```
Setting up vLLM repository...
Using existing vLLM repository at /home/congc/gitrepos/vllm
Skipping git fetch/checkout - using existing state
Current branch: vllm-grpc-upstream
...
Building and installing vLLM...
Installing vLLM with router support...
Building vllm-router from /home/congc/gitrepos/vllm/router using cargo
Running: cargo build --release
...
Successfully built vllm-router binary at /home/congc/gitrepos/vllm/router/target/release/vllm-router
...
Successfully installed vllm
Setup complete! vLLM environment is ready.
```

## Alternative: Manual Installation

If you want more control, install manually:

```bash
source ~/uv_env/vllm/bin/activate
cd /home/congc/gitrepos/vllm
VLLM_BUILD_ROUTER=1 VLLM_USE_PRECOMPILED=1 pip install -e . --no-deps
```

## 🚀 Test Localhost Mode

After installation, test immediately:

```bash
# Start vLLM with router
vllm serve Qwen/Qwen2.5-0.5B-Instruct \
    --enable-router-as-api-server \
    --port 8000
```

**In another terminal, test the API:**
```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "prompt": "Hello, world!",
    "max_tokens": 20
  }'
```

## Architecture

```
Single Command: vllm serve --enable-router-as-api-server
                    ↓
        ┌───────────┴───────────┐
        ↓                       ↓
   gRPC Server           Router (Rust)
   (port 50051)          (port 8000)
        ↑                       ↓
        └───────────────────────┘
              gRPC calls
```

## Troubleshooting

**If router binary not found after install:**
```bash
# Check if it exists
ls -lh /home/congc/gitrepos/vllm/router/target/release/vllm-router

# If not, build manually
cd /home/congc/gitrepos/vllm/router
cargo build --release
```

**If you see "setuptools-rust" error:**
- Ignore it! The router builds with cargo directly, setuptools-rust is optional.

**To verify installation:**
```bash
vllm --version
ls /home/congc/gitrepos/vllm/router/target/release/vllm-router
```

## Next Steps

- ✅ **You're done!** Just run `vllm serve MODEL --enable-router-as-api-server`
- 📖 See `ROUTER_INTEGRATION.md` for multi-node mode
- 📖 See `IMPLEMENTATION_SUMMARY.md` for technical details
