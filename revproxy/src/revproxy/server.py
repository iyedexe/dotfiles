"""The running proxy: owns the listening sockets and swaps in new routes
whenever the config file (or a TLS certificate it names) changes.

A reload is all-or-nothing: the new config is parsed, validated and its
handlers and TLS contexts built before anything is swapped, so a broken edit
is logged and the proxy keeps serving with the last good config. Requests
already in flight finish on the route they started on.
"""
from __future__ import annotations

import asyncio
import hashlib
import logging
import signal
import ssl
from pathlib import Path
from urllib.parse import unquote

import aiohttp
import watchfiles
from aiohttp import web

from .config import Config, ConfigError, Listener, load_config
from .handlers import Handler, build_handler
from .router import Router

log = logging.getLogger("revproxy")
access_log = logging.getLogger("revproxy.access")

ROUTE_KEY = "revproxy.route"


class ProxyServer:
    def __init__(self, config_path: str | Path) -> None:
        self.config_path = Path(config_path).resolve()
        self.config: Config | None = None
        self._router: Router[Handler] = Router([])
        self._session: aiohttp.ClientSession | None = None
        self._runner: web.AppRunner | None = None
        self._sites: dict[Listener, web.TCPSite] = {}
        self._ssl: dict[Listener, ssl.SSLContext] = {}
        self._fingerprint = b""
        self._reload_lock = asyncio.Lock()
        self._stopped = asyncio.Event()

    # ---------- lifecycle ----------

    async def start(self) -> None:
        """Load the config and start listening. Raises ConfigError if the
        initial config is bad, since there is nothing to fall back to."""
        config = load_config(self.config_path)
        self._session = aiohttp.ClientSession(
            auto_decompress=False,  # pass bodies through byte for byte
            connector=aiohttp.TCPConnector(limit=0),
            cookie_jar=aiohttp.DummyCookieJar(),  # never mix cookies between clients
            timeout=aiohttp.ClientTimeout(total=None),
        )
        app = web.Application(handler_args={"max_field_size": 65536})
        app.router.add_route("*", "/{tail:.*}", self._handle)
        app.on_response_prepare.append(self._add_response_headers)
        self._runner = web.AppRunner(app, access_log=access_log, handle_signals=False)
        await self._runner.setup()
        try:
            await self._apply(config)
            if not self._sites:
                raise OSError("could not listen on any configured address")
        except BaseException:
            await self.close()
            raise

    async def serve_forever(self) -> None:
        """Start, watch for changes and run until stop() or a signal."""
        await self.start()
        self._install_signal_handlers()
        watcher = asyncio.create_task(self._watch())
        try:
            await self._stopped.wait()
        finally:
            watcher.cancel()
            await asyncio.gather(watcher, return_exceptions=True)
            await self.close()

    def stop(self) -> None:
        self._stopped.set()

    async def close(self) -> None:
        if self._runner is not None:
            await self._runner.cleanup()
            self._runner = None
            self._sites.clear()
        if self._session is not None:
            await self._session.close()
            self._session = None

    # ---------- reloading ----------

    async def reload(self, *, force: bool = False) -> bool:
        """Re-read the config. Returns True if a new config was applied.

        Without force, nothing happens unless the config or TLS files'
        contents actually changed, which absorbs the burst of events editors
        produce on a single save."""
        async with self._reload_lock:
            if not force and self._current_fingerprint() == self._fingerprint:
                return False
            try:
                config = load_config(self.config_path)
                await self._apply(config)
            except (ConfigError, ssl.SSLError, OSError) as e:
                log.error("reload failed, still serving the previous config: %s", e)
                return False
            log.info("config reloaded: %d route(s) on %s",
                     len(config.routes), ", ".join(map(str, config.listeners)))
            return True

    async def _apply(self, config: Config) -> None:
        # Build everything that can fail first, then swap.
        router = Router((route, build_handler(route, self._session)) for route in config.routes)
        fresh_ssl = {lst: _ssl_context(lst) for lst in config.listeners if lst.tls}

        _set_log_level(config)
        self._router = router
        self.config = config
        self._fingerprint = self._current_fingerprint()
        await self._sync_listeners(config.listeners, fresh_ssl)

    async def _sync_listeners(self, wanted: tuple[Listener, ...], fresh_ssl: dict[Listener, ssl.SSLContext]) -> None:
        for listener in list(self._sites):
            if listener not in wanted:
                await self._sites.pop(listener).stop()  # open connections are left to finish
                self._ssl.pop(listener, None)
                log.info("stopped listening on %s", listener)

        for listener in wanted:
            if listener in self._sites:
                if listener.tls:
                    # Swap the certificate into the live context: new handshakes
                    # get it straight away without closing the socket.
                    self._ssl[listener].load_cert_chain(listener.tls_cert, listener.tls_key)
                continue
            self._ssl[listener] = context = fresh_ssl.get(listener)
            site = web.TCPSite(self._runner, listener.host, listener.port, ssl_context=context)
            try:
                await site.start()
            except OSError as e:
                self._ssl.pop(listener, None)
                log.error("cannot listen on %s: %s", listener, e.strerror or e)
                continue
            self._sites[listener] = site
            log.info("listening on %s", listener)

    def _current_fingerprint(self) -> bytes:
        files = {self.config_path} | (self.config.watched_files if self.config else set())
        digest = hashlib.sha256()
        for path in sorted(files):
            digest.update(str(path).encode())
            try:
                digest.update(path.read_bytes())
            except OSError:
                digest.update(b"\0missing")
        return digest.digest()

    async def _watch(self) -> None:
        """Watch the directories holding the config and TLS files. Watching
        the directory rather than the file survives editors and tools that
        save by writing a new file and renaming it over the old one."""
        while True:
            dirs = sorted({p.parent for p in self._watched_files() if p.parent.is_dir()})
            log.debug("watching %s", ", ".join(map(str, dirs)))
            async for _ in watchfiles.awatch(*dirs, debounce=300, step=50):
                await self.reload()
                new_dirs = sorted({p.parent for p in self._watched_files() if p.parent.is_dir()})
                if new_dirs != dirs:
                    break  # a TLS file moved to another directory: restart the watch

    def _watched_files(self) -> frozenset[Path]:
        return (self.config.watched_files if self.config else frozenset()) | {self.config_path}

    def _install_signal_handlers(self) -> None:
        loop = asyncio.get_running_loop()
        try:
            loop.add_signal_handler(signal.SIGINT, self.stop)
            loop.add_signal_handler(signal.SIGTERM, self.stop)
            loop.add_signal_handler(signal.SIGHUP, lambda: asyncio.ensure_future(self.reload(force=True)))
        except (NotImplementedError, AttributeError):
            pass  # Windows: Ctrl+C still arrives as KeyboardInterrupt

    # ---------- request handling ----------

    async def _handle(self, request: web.Request) -> web.StreamResponse:
        if _has_dot_segments(request.raw_path):
            # Refuse rather than normalise, so the route we match and the path
            # the upstream sees can never disagree about "..".
            raise web.HTTPBadRequest(text="400 Bad Request: '.' and '..' path segments are not allowed\n")
        router = self._router  # one snapshot per request, even if a reload lands mid-request
        match = router.match(request.host, request.path)
        if match is None:
            raise web.HTTPNotFound(text="404 Not Found: no route for this host and path\n")
        request[ROUTE_KEY] = match.route
        return await match.handler(request, match)

    @staticmethod
    async def _add_response_headers(request: web.Request, response: web.StreamResponse) -> None:
        route = request.get(ROUTE_KEY)
        if route is not None:
            for name, value in route.response_headers:
                response.headers[name] = value


def _has_dot_segments(raw_path: str) -> bool:
    path = unquote(raw_path.partition("?")[0])
    return any(segment in (".", "..") for segment in path.replace("\\", "/").split("/"))


def _ssl_context(listener: Listener) -> ssl.SSLContext:
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    try:
        context.load_cert_chain(listener.tls_cert, listener.tls_key)
    except (OSError, ssl.SSLError) as e:
        raise ConfigError(f"{listener}: cannot load TLS certificate: {e}") from e
    return context


def _set_log_level(config: Config) -> None:
    logging.getLogger("revproxy").setLevel(config.log_level.upper())
    access_log.setLevel(logging.INFO)  # independent of log_level
    access_log.disabled = not config.access_log
