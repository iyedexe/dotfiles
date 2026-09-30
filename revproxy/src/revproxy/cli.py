from __future__ import annotations

import argparse
import asyncio
import logging
import sys

from .config import ConfigError, load_config


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="revproxy",
        description="Reverse proxy that reloads its TOML config whenever the file changes.",
    )
    parser.add_argument("-c", "--config", default="revproxy.toml",
                        help="path to the config file (default: %(default)s)")
    parser.add_argument("--check", action="store_true",
                        help="validate the config, print the routes and exit")
    args = parser.parse_args(argv)

    logging.basicConfig(format="%(asctime)s %(levelname)-7s %(name)s: %(message)s", level=logging.INFO)

    logging.getLogger("watchfiles").setLevel(logging.WARNING)  # its "N changes detected" is noise

    if args.check:
        return _check(args.config)

    from .server import ProxyServer  # deferred so --check stays fast

    try:
        asyncio.run(ProxyServer(args.config).serve_forever())
    except ConfigError as e:
        logging.getLogger("revproxy").error("%s", e)
        return 1
    except OSError as e:
        logging.getLogger("revproxy").error("%s", e)
        return 1
    except KeyboardInterrupt:
        pass
    return 0


def _check(path: str) -> int:
    try:
        config = load_config(path)
    except ConfigError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    print(f"{config.path}: OK")
    for listener in config.listeners:
        print(f"  listen  {listener}")
    for route in config.routes:
        hosts = ",".join(route.hosts) or "*"
        kind = type(route.target).__name__.removesuffix("Target").lower()
        print(f"  route   {route.name}: {hosts}{route.path} -> {kind}")
    return 0
