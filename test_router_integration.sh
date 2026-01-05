#!/bin/bash

# Test script for vLLM Router Integration
# This script tests both localhost and multi-node modes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  vLLM Router Integration Test Suite${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Configuration
TEST_MODEL="${TEST_MODEL:-Qwen/Qwen3-0.6B}"
ROUTER_PORT="${ROUTER_PORT:-8000}"
GRPC_PORT="${GRPC_PORT:-50051}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"  # 5 minutes

# Test functions
print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check if vllm is installed
    if ! command -v vllm &> /dev/null; then
        print_error "vllm command not found. Please install vLLM first."
        exit 1
    fi

    # Check if router is installed
    if ! python -c "from vllm_router.router import Router" 2>/dev/null; then
        print_warning "Router not installed. Installing..."
        VLLM_BUILD_ROUTER=1 pip install -e .[router]
    fi

    # Check if vllm-router command exists
    if ! command -v vllm-router &> /dev/null; then
        print_error "vllm-router command not found. Router installation may have failed."
        exit 1
    fi

    print_success "All prerequisites met"
}

# Test localhost mode
test_localhost_mode() {
    print_step "Testing Localhost Mode..."

    # Start vLLM with router
    print_info "Starting vLLM with --enable-router-as-api-server..."

    vllm serve "$TEST_MODEL" \
        --enable-router-as-api-server \
        --port "$ROUTER_PORT" \
        --disable-log-requests \
        &
    VLLM_PID=$!

    # Wait for server to start
    print_info "Waiting for server to start..."
    sleep 10

    # Check if process is still running
    if ! ps -p $VLLM_PID > /dev/null; then
        print_error "vLLM process died. Check logs above."
        return 1
    fi

    # Test health endpoint
    print_info "Testing health endpoint..."
    if curl -s -f http://localhost:$ROUTER_PORT/health > /dev/null; then
        print_success "Health check passed"
    else
        print_error "Health check failed"
        kill $VLLM_PID 2>/dev/null || true
        return 1
    fi

    # Test completions endpoint
    print_info "Testing /v1/completions endpoint..."
    RESPONSE=$(curl -s -X POST http://localhost:$ROUTER_PORT/v1/completions \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"prompt\": \"Hello\",
            \"max_tokens\": 10
        }")

    if echo "$RESPONSE" | grep -q "choices"; then
        print_success "Completions endpoint works"
        print_info "Response: $RESPONSE"
    else
        print_error "Completions endpoint failed"
        print_info "Response: $RESPONSE"
        kill $VLLM_PID 2>/dev/null || true
        return 1
    fi

    # Cleanup
    print_info "Stopping vLLM..."
    kill $VLLM_PID 2>/dev/null || true
    wait $VLLM_PID 2>/dev/null || true

    print_success "Localhost mode test passed!"
}

# Test multi-node mode
test_multinode_mode() {
    print_step "Testing Multi-Node Mode..."

    # Start vLLM engine in headless mode
    print_info "Starting vLLM engine (headless mode)..."

    vllm serve "$TEST_MODEL" \
        --headless \
        --port "$GRPC_PORT" \
        --disable-log-requests \
        &
    ENGINE_PID=$!

    # Wait for engine to start
    print_info "Waiting for engine to start..."
    sleep 10

    # Check if engine is running
    if ! ps -p $ENGINE_PID > /dev/null; then
        print_error "vLLM engine process died. Check logs above."
        return 1
    fi

    # Start router separately
    print_info "Starting router..."

    vllm-router \
        --worker-urls "http://127.0.0.1:$GRPC_PORT" \
        --policy cache_aware \
        --port "$ROUTER_PORT" \
        --model-path "$TEST_MODEL" \
        &
    ROUTER_PID=$!

    # Wait for router to start
    print_info "Waiting for router to start..."
    sleep 5

    # Check if router is running
    if ! ps -p $ROUTER_PID > /dev/null; then
        print_error "Router process died. Check logs above."
        kill $ENGINE_PID 2>/dev/null || true
        return 1
    fi

    # Test health endpoint
    print_info "Testing health endpoint..."
    if curl -s -f http://localhost:$ROUTER_PORT/health > /dev/null; then
        print_success "Health check passed"
    else
        print_error "Health check failed"
        kill $ROUTER_PID $ENGINE_PID 2>/dev/null || true
        return 1
    fi

    # Test completions endpoint
    print_info "Testing /v1/completions endpoint..."
    RESPONSE=$(curl -s -X POST http://localhost:$ROUTER_PORT/v1/completions \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$TEST_MODEL\",
            \"prompt\": \"Hello\",
            \"max_tokens\": 10
        }")

    if echo "$RESPONSE" | grep -q "choices"; then
        print_success "Completions endpoint works"
        print_info "Response: $RESPONSE"
    else
        print_error "Completions endpoint failed"
        print_info "Response: $RESPONSE"
        kill $ROUTER_PID $ENGINE_PID 2>/dev/null || true
        return 1
    fi

    # Cleanup
    print_info "Stopping router and engine..."
    kill $ROUTER_PID 2>/dev/null || true
    kill $ENGINE_PID 2>/dev/null || true
    wait $ROUTER_PID 2>/dev/null || true
    wait $ENGINE_PID 2>/dev/null || true

    print_success "Multi-node mode test passed!"
}

# Main test execution
main() {
    # Check prerequisites
    check_prerequisites

    echo ""
    echo -e "${BLUE}Starting tests...${NC}"
    echo ""

    # Test localhost mode
    if test_localhost_mode; then
        echo ""
        print_success "✓ Localhost mode: PASSED"
    else
        echo ""
        print_error "✗ Localhost mode: FAILED"
        exit 1
    fi

    echo ""
    sleep 5  # Give time for ports to be released

    # Test multi-node mode
    if test_multinode_mode; then
        echo ""
        print_success "✓ Multi-node mode: PASSED"
    else
        echo ""
        print_error "✗ Multi-node mode: FAILED"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}  All tests passed! 🎉${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Read ROUTER_INTEGRATION.md for detailed usage"
    echo "2. Try localhost mode: vllm serve MODEL --enable-router-as-api-server"
    echo "3. Try multi-node mode: vllm-router --worker-urls http://host:port"
    echo ""
}

# Run main function
main "$@"
