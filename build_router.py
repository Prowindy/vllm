#!/usr/bin/env python3
"""
Build vLLM router binary using cargo.
This script is called automatically during pip install when VLLM_BUILD_ROUTER=1
"""

import os
import subprocess
import sys
from pathlib import Path


def build_router():
    """Build the router using cargo."""
    # Find vLLM root directory
    script_dir = Path(__file__).parent
    vllm_root = script_dir
    router_dir = vllm_root / "router"

    if not router_dir.exists():
        print(f"Router directory not found at {router_dir}")
        return False

    # Check if cargo is available
    try:
        subprocess.check_call(["cargo", "--version"], stdout=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("ERROR: cargo not found. Install Rust from https://rustup.rs/")
        return False

    print("=" * 60)
    print("Building vLLM Router with Cargo")
    print("=" * 60)
    print(f"Router directory: {router_dir}")
    print()

    # Build router
    try:
        subprocess.check_call(
            ["cargo", "build", "--release"],
            cwd=router_dir,
        )

        router_binary = router_dir / "target" / "release" / "vllm-router"
        if router_binary.exists():
            size_mb = router_binary.stat().st_size / (1024 * 1024)
            print()
            print("=" * 60)
            print(f"✓ Router built successfully!")
            print(f"  Binary: {router_binary}")
            print(f"  Size: {size_mb:.1f} MB")
            print("=" * 60)
            return True
        else:
            print("ERROR: Router binary not found after build")
            return False

    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to build router: {e}")
        return False


if __name__ == "__main__":
    success = build_router()
    sys.exit(0 if success else 1)
