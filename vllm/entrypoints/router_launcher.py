# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright contributors to the vLLM project
"""
Router process launcher for vLLM localhost mode.

This module handles launching and managing the Rust-based router process
when vLLM is run with --enable-router-as-api-server flag.
"""

import argparse
import logging
import multiprocessing
import os
import signal
import sys
import time
from typing import Optional

from vllm.logger import init_logger

logger = init_logger(__name__)


class RouterProcess:
    """Manager for the router subprocess."""

    def __init__(self, args: argparse.Namespace):
        """Initialize router process manager.

        Args:
            args: Namespace containing router configuration from vllm serve
        """
        self.args = args
        self.process: Optional[multiprocessing.Process] = None
        self._should_stop = False

    def start(self) -> None:
        """Start the router process."""
        try:
            # Import router launcher (this will fail if router is not installed)
            from vllm_router.launch_router import launch_router
            from vllm_router.router_args import RouterArgs
        except ImportError as e:
            logger.error(
                "Failed to import vllm_router. Make sure the router is installed. "
                "Install it with: VLLM_BUILD_ROUTER=1 pip install -e .[router]"
            )
            raise RuntimeError(
                "Router is not installed. Cannot use --enable-router-as-api-server"
            ) from e

        # Build router args from vllm serve args
        router_args = self._build_router_args()

        # Launch router in a separate process
        logger.info("Starting router process...")
        self.process = multiprocessing.Process(
            target=self._run_router,
            args=(router_args,),
            name="vllm-router",
        )
        self.process.start()

        # Wait a bit to ensure router starts successfully
        time.sleep(2)
        if not self.process.is_alive():
            raise RuntimeError("Router process failed to start")

        logger.info(
            "Router started successfully on http://%s:%d",
            router_args.host,
            router_args.port,
        )

    def _run_router(self, router_args) -> None:
        """Run the router in subprocess.

        Args:
            router_args: RouterArgs instance with configuration
        """
        try:
            from vllm_router.launch_router import launch_router

            # Set process title for easier identification
            try:
                import setproctitle
                setproctitle.setproctitle("vllm::router")
            except ImportError:
                pass

            # Launch the router
            launch_router(router_args)
        except Exception as e:
            logger.error("Router process failed: %s", e)
            raise

    def _build_router_args(self):
        """Build RouterArgs from vllm serve arguments.

        Returns:
            RouterArgs instance configured for localhost mode
        """
        from vllm_router.router_args import RouterArgs

        # Determine worker URL (gRPC endpoint)
        # In localhost mode, the vllm engine runs a gRPC server
        grpc_host = getattr(self.args, "grpc_host", "127.0.0.1")
        grpc_port = getattr(self.args, "grpc_port", 50051)
        worker_url = f"http://{grpc_host}:{grpc_port}"

        # Router should listen on the user-specified host/port
        router_host = self.args.host or "0.0.0.0"
        router_port = self.args.port or 8000

        # Build router args
        policy = getattr(self.args, "router_policy", "consistent_hash")
        logger.info(f"Router policy from args: {policy}")

        router_args = RouterArgs(
            worker_urls=[worker_url],
            host=router_host,
            port=router_port,
            # Pass through router-specific args if they exist
            policy=policy,
            api_key=getattr(self.args, "api_key", None),
            log_level=getattr(self.args, "router_log_level", None),
            model_path=getattr(self.args, "model", None),
            tokenizer_path=getattr(self.args, "tokenizer", None),
            # Rate limiting configuration
            max_concurrent_requests=getattr(
                self.args, "router_max_concurrent_requests", 32768
            ),
            request_timeout_secs=getattr(self.args, "router_request_timeout", 1800),
            # Prometheus configuration
            prometheus_port=getattr(self.args, "router_prometheus_port", None),
            prometheus_host=getattr(self.args, "router_prometheus_host", None),
        )

        return router_args

    def stop(self) -> None:
        """Stop the router process gracefully."""
        if self.process and self.process.is_alive():
            logger.info("Stopping router process...")
            self.process.terminate()

            # Wait for graceful shutdown
            self.process.join(timeout=10)

            # Force kill if still alive
            if self.process.is_alive():
                logger.warning("Router process did not stop gracefully, killing...")
                self.process.kill()
                self.process.join()

            logger.info("Router process stopped")

    def is_alive(self) -> bool:
        """Check if router process is still running."""
        return self.process is not None and self.process.is_alive()


def launch_router_for_localhost(args: argparse.Namespace) -> RouterProcess:
    """Launch router for localhost mode.

    This function creates and starts a router process that will handle
    HTTP API requests while vLLM engine handles the actual inference via gRPC.

    Args:
        args: Command-line arguments from vllm serve

    Returns:
        RouterProcess instance managing the router subprocess

    Raises:
        RuntimeError: If router cannot be started
    """
    router_manager = RouterProcess(args)
    router_manager.start()
    return router_manager
