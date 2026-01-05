#!/bin/bash
# Test Localhost Mode for vLLM Router Integration
# Run this script to test the localhost mode

set -e

echo "=== Testing vLLM Localhost Mode with Router ==="
echo ""

# Activate environment
source ~/uv_env/vllm/bin/activate

# Check prerequisites
echo "1. Checking prerequisites..."
if [ ! -f "/home/congc/gitrepos/vllm/router/target/release/vllm-router" ]; then
    echo "ERROR: Router binary not found. Building it now..."
    cd /home/congc/gitrepos/vllm/router
    cargo build --release
    echo "Router binary built successfully!"
fi

echo "✓ Router binary exists"
echo "✓ vLLM version: $(vllm --version)"
echo ""

# Start vLLM in localhost mode
echo "2. Starting vLLM with router (localhost mode)..."
echo ""
echo "Run this command in a separate terminal:"
echo ""
echo "  source ~/uv_env/vllm/bin/activate"
echo "  vllm serve Qwen/Qwen2.5-0.5B-Instruct --enable-router-as-api-server --port 8000"
echo ""
echo "Wait for both processes to start, then test with:"
echo ""
echo "  curl http://localhost:8000/v1/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{"
echo "      \"model\": \"Qwen/Qwen2.5-0.5B-Instruct\","
echo "      \"prompt\": \"Once upon a time\","
echo "      \"max_tokens\": 50"
echo "    }'"
echo ""
echo "=== End of instructions ==="
