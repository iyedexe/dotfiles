"""Load and validate the TOML config file into immutable dataclasses.

Every problem is reported as a ConfigError naming the offending table, so a
bad edit during a hot reload can be logged and the previous config kept.
"""
from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from yarl import URL

LOG_LEVELS = ("debug", "info", "warning", "error", "critical")
REDIRECT_CODES = (301, 302, 303, 307, 308)
TARGET_KINDS = ("proxy", "static", "redirect", "respond")


class ConfigError(Exception):
    pass


@dataclass(frozen=True)
class Listener:
    host: str
    port: int
    tls_cert: Path | None = None
    tls_key: Path | None = None

    @property
    def tls(self) -> bool:
        return self.tls_cert is not None

    def __str__(self) -> str:
        scheme = "https" if self.tls else "http"
        return f"{scheme}://{self.host}:{self.port}"


@dataclass(frozen=True)
class ProxyTarget:
    upstreams: tuple[URL, ...]
    strip_prefix: bool
    preserve_host: bool
    timeout: float
    request_headers: tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class StaticTarget:
    root: Path
    index: str
    spa: bool


@dataclass(frozen=True)
class RedirectTarget:
    location: str
    status: int
    keep_path: bool


@dataclass(frozen=True)
class RespondTarget:
    body: str
    status: int
    content_type: str


Target = ProxyTarget | StaticTarget | RedirectTarget | RespondTarget


@dataclass(frozen=True)
class Route:
    name: str
    hosts: tuple[str, ...]  # empty means any host
    path: str
    target: Target
    response_headers: tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class Config:
    path: Path
    log_level: str
    access_log: bool
    listeners: tuple[Listener, ...]
    routes: tuple[Route, ...]

    @property
    def watched_files(self) -> frozenset[Path]:
        """The config file plus every TLS file, all of which trigger a reload."""
        files = {self.path}
        for listener in self.listeners:
            if listener.tls:
                files |= {listener.tls_cert, listener.tls_key}
        return frozenset(files)


def load_config(path: str | Path) -> Config:
    path = Path(path).resolve()
    try:
        with path.open("rb") as f:
            data = tomllib.load(f)
    except OSError as e:
        raise ConfigError(f"cannot read {path}: {e.strerror}") from e
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path}: invalid TOML: {e}") from e
    return parse_config(data, path)


def parse_config(data: dict[str, Any], path: Path) -> Config:
    base_dir = path.parent
    _check_keys(data, {"server", "listeners", "routes"}, "top level")

    server = _table(data.get("server", {}), "[server]")
    _check_keys(server, {"log_level", "access_log"}, "[server]")
    log_level = _get(server, "log_level", str, "info", "[server]").lower()
    if log_level not in LOG_LEVELS:
        raise ConfigError(f"[server] log_level must be one of {', '.join(LOG_LEVELS)}")
    access_log = _get(server, "access_log", bool, True, "[server]")

    raw_listeners = _array(data.get("listeners", [{"port": 8080}]), "listeners")
    listeners = tuple(
        _parse_listener(_table(item, f"listeners[{i}]"), f"listeners[{i}]", base_dir)
        for i, item in enumerate(raw_listeners)
    )
    if not listeners:
        raise ConfigError("at least one [[listeners]] entry is required")
    addresses = [(lst.host, lst.port) for lst in listeners]
    if len(set(addresses)) != len(addresses):
        raise ConfigError("two [[listeners]] entries use the same host and port")

    raw_routes = _array(data.get("routes", []), "routes")
    routes = tuple(
        _parse_route(_table(item, f"routes[{i}]"), i, base_dir)
        for i, item in enumerate(raw_routes)
    )
    return Config(path, log_level, access_log, listeners, routes)


def _parse_listener(table: dict[str, Any], where: str, base_dir: Path) -> Listener:
    _check_keys(table, {"host", "port", "tls_cert", "tls_key"}, where)
    host = _get(table, "host", str, "0.0.0.0", where)
    port = _get(table, "port", int, None, where)
    if not 0 < port < 65536:
        raise ConfigError(f"{where}: port must be between 1 and 65535")
    cert = _get(table, "tls_cert", str, "", where)
    key = _get(table, "tls_key", str, "", where)
    if bool(cert) != bool(key):
        raise ConfigError(f"{where}: tls_cert and tls_key must be set together")
    if not cert:
        return Listener(host, port)
    return Listener(host, port, _resolve(base_dir, cert), _resolve(base_dir, key))


def _parse_route(table: dict[str, Any], index: int, base_dir: Path) -> Route:
    name = table.get("name", f"routes[{index}]")
    where = f"route {name!r}" if "name" in table else name
    kinds = [kind for kind in TARGET_KINDS if kind in table]
    if len(kinds) != 1:
        raise ConfigError(f"{where}: set exactly one of {', '.join(TARGET_KINDS)}")
    kind = kinds[0]

    common = {"name", "host", "path", "response_headers", kind}
    extra = {
        "proxy": {"strip_prefix", "preserve_host", "timeout", "request_headers"},
        "static": {"index", "spa"},
        "redirect": {"status", "keep_path"},
        "respond": {"status", "content_type"},
    }[kind]
    _check_keys(table, common | extra, where)

    hosts = table.get("host", [])
    if isinstance(hosts, str):
        hosts = [hosts]
    if not isinstance(hosts, list) or not all(isinstance(h, str) and h for h in hosts):
        raise ConfigError(f"{where}: host must be a string or a list of strings")
    hosts = tuple(h.lower().rstrip(".") for h in hosts)
    for h in hosts:
        if "*" in h and not (h.startswith("*.") and "*" not in h[2:]):
            raise ConfigError(f"{where}: wildcard host {h!r} must look like '*.example.com'")

    path = _get(table, "path", str, "/", where)
    if not path.startswith("/"):
        raise ConfigError(f"{where}: path must start with '/'")
    path = path.rstrip("/") or "/"

    parse_target = {
        "proxy": _parse_proxy,
        "static": _parse_static,
        "redirect": _parse_redirect,
        "respond": _parse_respond,
    }[kind]
    target = parse_target(table, where, base_dir)
    response_headers = _headers(table, "response_headers", where)
    return Route(str(name), hosts, path, target, response_headers)


def _parse_proxy(table: dict[str, Any], where: str, base_dir: Path) -> ProxyTarget:
    raw = table["proxy"]
    raw = [raw] if isinstance(raw, str) else raw
    if not isinstance(raw, list) or not raw or not all(isinstance(u, str) for u in raw):
        raise ConfigError(f"{where}: proxy must be a URL or a non-empty list of URLs")
    upstreams = []
    for text in raw:
        url = URL(text)
        if url.scheme not in ("http", "https") or not url.host:
            raise ConfigError(f"{where}: upstream {text!r} must be an http:// or https:// URL")
        if url.query_string or url.fragment:
            raise ConfigError(f"{where}: upstream {text!r} must not have a query or fragment")
        upstreams.append(url)
    timeout = _get(table, "timeout", (int, float), 60, where)
    if timeout <= 0:
        raise ConfigError(f"{where}: timeout must be positive")
    return ProxyTarget(
        upstreams=tuple(upstreams),
        strip_prefix=_get(table, "strip_prefix", bool, False, where),
        preserve_host=_get(table, "preserve_host", bool, False, where),
        timeout=float(timeout),
        request_headers=_headers(table, "request_headers", where),
    )


def _parse_static(table: dict[str, Any], where: str, base_dir: Path) -> StaticTarget:
    root = _resolve(base_dir, _get(table, "static", str, None, where))
    if not root.is_dir():
        raise ConfigError(f"{where}: static directory {root} does not exist")
    index = _get(table, "index", str, "index.html", where)
    return StaticTarget(root, index, _get(table, "spa", bool, False, where))


def _parse_redirect(table: dict[str, Any], where: str, base_dir: Path) -> RedirectTarget:
    status = _get(table, "status", int, 302, where)
    if status not in REDIRECT_CODES:
        raise ConfigError(f"{where}: redirect status must be one of {REDIRECT_CODES}")
    return RedirectTarget(
        location=_get(table, "redirect", str, None, where),
        status=status,
        keep_path=_get(table, "keep_path", bool, False, where),
    )


def _parse_respond(table: dict[str, Any], where: str, base_dir: Path) -> RespondTarget:
    status = _get(table, "status", int, 200, where)
    if not 100 <= status <= 599:
        raise ConfigError(f"{where}: status must be a valid HTTP status code")
    return RespondTarget(
        body=_get(table, "respond", str, None, where),
        status=status,
        content_type=_get(table, "content_type", str, "text/plain", where),
    )


# ---------- helpers ----------

_MISSING = object()


def _get(table: dict[str, Any], key: str, kind: type | tuple[type, ...], default: Any, where: str) -> Any:
    value = table.get(key, _MISSING)
    if value is _MISSING:
        if default is None:
            raise ConfigError(f"{where}: {key} is required")
        return default
    # bool is a subclass of int, so reject it explicitly where a number is expected
    if not isinstance(value, kind) or (isinstance(value, bool) and kind is not bool):
        names = kind.__name__ if isinstance(kind, type) else "number"
        raise ConfigError(f"{where}: {key} must be a {names}")
    return value


def _headers(table: dict[str, Any], key: str, where: str) -> tuple[tuple[str, str], ...]:
    value = table.get(key, {})
    if not isinstance(value, dict) or not all(isinstance(v, str) for v in value.values()):
        raise ConfigError(f"{where}: {key} must be a table of string values")
    return tuple(value.items())


def _table(value: Any, where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ConfigError(f"{where} must be a table")
    return value


def _array(value: Any, name: str) -> list[Any]:
    if not isinstance(value, list):
        raise ConfigError(f"{name} must be an array of tables, written [[{name}]]")
    return value


def _check_keys(table: dict[str, Any], allowed: set[str], where: str) -> None:
    unknown = sorted(set(table) - allowed)
    if unknown:
        raise ConfigError(f"{where}: unknown key(s) {', '.join(unknown)}")


def _resolve(base_dir: Path, value: str) -> Path:
    """Relative paths in the config are relative to the config file, not the cwd."""
    return (base_dir / Path(value).expanduser()).resolve()
