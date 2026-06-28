#!/usr/bin/env python3
"""Network-based health check for a smart TV."""

import argparse
import json
import socket
import sys
import time

DEFAULT_PORTS = {
    80: "http",
    443: "https",
    8001: "samsung-tizen",
    8002: "samsung-tizen-ssl",
    3000: "lg-webos",
    3001: "lg-webos-ssl",
    8060: "roku-ecp",
    1925: "philips-jointspace",
    1926: "philips-jointspace-ssl",
}


def check_port(host, port, timeout=2.0):
    start = time.monotonic()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True, (time.monotonic() - start) * 1000
    except OSError:
        return False, None


def tv_health_check(host, ports=None, timeout=2.0):
    """Check whether a smart TV at `host` is reachable on common control ports."""
    ports = ports or list(DEFAULT_PORTS)
    results = []
    for port in ports:
        is_open, latency_ms = check_port(host, port, timeout)
        results.append(
            {
                "port": port,
                "service": DEFAULT_PORTS.get(port, "unknown"),
                "open": is_open,
                "latency_ms": round(latency_ms, 2) if latency_ms is not None else None,
            }
        )

    open_results = [r for r in results if r["open"]]
    status = "healthy" if open_results else "unreachable"
    latency = min((r["latency_ms"] for r in open_results), default=None)

    return {
        "host": host,
        "status": status,
        "latency_ms": latency,
        "ports": results,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Check whether a smart TV is reachable on the network."
    )
    parser.add_argument("host", help="IP address or hostname of the TV")
    parser.add_argument(
        "--port",
        type=int,
        action="append",
        dest="ports",
        help="Port to check (repeatable). Defaults to common smart TV ports.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=2.0,
        help="Per-port connection timeout in seconds (default: 2.0)",
    )
    args = parser.parse_args()

    result = tv_health_check(args.host, ports=args.ports, timeout=args.timeout)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["status"] == "healthy" else 1)


if __name__ == "__main__":
    main()
