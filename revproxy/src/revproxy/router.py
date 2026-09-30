"""Pick the route for a request from its Host header and path.

Precedence: an exact host beats a wildcard host, which beats a route with no
host; within the same host rank, the longest path prefix wins; remaining ties
go to whichever route comes first in the config file.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Generic, Iterable, TypeVar

from .config import Route

H = TypeVar("H")

_ANY_HOST, _WILDCARD_HOST, _EXACT_HOST = 0, 1, 2


@dataclass(frozen=True)
class Match(Generic[H]):
    route: Route
    handler: H
    remainder: str  # the part of the path after the route prefix ("" or "/...")


@dataclass(frozen=True)
class _Entry(Generic[H]):
    host: str | None
    rank: int
    route: Route
    handler: H


class Router(Generic[H]):
    def __init__(self, routes: Iterable[tuple[Route, H]]) -> None:
        entries = []
        for route, handler in routes:
            for host in route.hosts or (None,):
                rank = _ANY_HOST if host is None else _WILDCARD_HOST if host.startswith("*.") else _EXACT_HOST
                entries.append(_Entry(host, rank, route, handler))
        # sorted() is stable, so equal keys keep config order even with reverse=True
        self._entries = sorted(entries, key=lambda e: (e.rank, len(e.route.path)), reverse=True)

    def match(self, host: str, path: str) -> Match[H] | None:
        host = normalize_host(host)
        for entry in self._entries:
            if not _host_matches(entry.host, host):
                continue
            remainder = _strip_prefix(entry.route.path, path)
            if remainder is not None:
                return Match(entry.route, entry.handler, remainder)
        return None


def normalize_host(host: str) -> str:
    """Lowercase and drop the port: 'Example.COM:8080' -> 'example.com'."""
    host = host.strip().lower()
    if host.startswith("["):  # IPv6 literal, e.g. [::1]:8080
        end = host.find("]")
        return host[: end + 1] if end != -1 else host
    return host.rsplit(":", 1)[0].rstrip(".")


def _host_matches(pattern: str | None, host: str) -> bool:
    if pattern is None:
        return True
    if pattern.startswith("*."):
        return host.endswith(pattern[1:])
    return host == pattern


def _strip_prefix(prefix: str, path: str) -> str | None:
    """'/api' matches '/api' and '/api/x' but not '/apix'. Returns what is left."""
    if prefix == "/":
        return path
    if path == prefix or path.startswith(prefix + "/"):
        return path[len(prefix):]
    return None
