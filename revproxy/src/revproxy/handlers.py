"""One handler per route kind. A handler is built once per config load and
called for every request its route matches."""
from __future__ import annotations

import asyncio
import itertools
import logging
from typing import Protocol

import aiohttp
from aiohttp import WSMsgType, web
from multidict import CIMultiDict, MultiMapping
from yarl import URL

from .config import ProxyTarget, RedirectTarget, RespondTarget, Route, StaticTarget, Target
from .router import Match

log = logging.getLogger("revproxy")

# Headers that describe a single connection and must not be forwarded (RFC 9110 7.6.1).
HOP_BY_HOP = frozenset({
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "proxy-connection", "te", "trailer", "transfer-encoding", "upgrade",
})
# The WebSocket handshake is redone by aiohttp on the upstream side.
WEBSOCKET_HANDSHAKE = frozenset({
    "sec-websocket-key", "sec-websocket-version", "sec-websocket-extensions",
    "sec-websocket-protocol", "sec-websocket-accept",
})


class Handler(Protocol):
    async def __call__(self, request: web.Request, match: Match[Handler]) -> web.StreamResponse: ...


def build_handler(route: Route, session: aiohttp.ClientSession) -> Handler:
    target: Target = route.target
    if isinstance(target, ProxyTarget):
        return ProxyHandler(route, target, session)
    if isinstance(target, StaticTarget):
        return StaticHandler(target)
    if isinstance(target, RedirectTarget):
        return RedirectHandler(target)
    return RespondHandler(target)


class ProxyHandler:
    def __init__(self, route: Route, target: ProxyTarget, session: aiohttp.ClientSession) -> None:
        self._route = route
        self._target = target
        self._session = session
        self._next = itertools.count()
        self._timeout = aiohttp.ClientTimeout(
            total=None, connect=min(10.0, target.timeout), sock_read=target.timeout
        )

    async def __call__(self, request: web.Request, match: Match[Handler]) -> web.StreamResponse:
        upstreams = self._target.upstreams
        start = next(self._next)
        # Round robin, failing over to the next upstream when one refuses the
        # connection. The request body has not been read yet at that point.
        for i in range(len(upstreams)):
            upstream = upstreams[(start + i) % len(upstreams)]
            try:
                if _is_websocket(request):
                    return await self._websocket(request, match, upstream)
                return await self._http(request, match, upstream)
            except aiohttp.ClientConnectorError as e:
                log.warning("route %s: upstream %s unreachable: %s", self._route.name, upstream, e.os_error)
        raise web.HTTPBadGateway(text="502 Bad Gateway: no upstream reachable\n")

    async def _http(self, request: web.Request, match: Match[Handler], upstream: URL) -> web.StreamResponse:
        url = self._upstream_url(request, match, upstream)
        try:
            upstream_resp = await self._session.request(
                request.method,
                url,
                headers=self._request_headers(request),
                data=request.content if request.body_exists else None,
                allow_redirects=False,
                timeout=self._timeout,
            )
        except aiohttp.ClientConnectorError:
            raise
        except TimeoutError:
            raise web.HTTPGatewayTimeout(text="504 Gateway Timeout\n") from None
        except aiohttp.ClientError as e:
            log.warning("route %s: request to %s failed: %s", self._route.name, url, e)
            raise web.HTTPBadGateway(text="502 Bad Gateway\n") from None

        try:
            resp = web.StreamResponse(status=upstream_resp.status, reason=upstream_resp.reason)
            for name, value in _strip_hop_by_hop(upstream_resp.headers).items():
                resp.headers.add(name, value)
            await resp.prepare(request)
            try:
                async for chunk in upstream_resp.content.iter_any():
                    await resp.write(chunk)
            except (aiohttp.ClientError, TimeoutError) as e:
                # Headers are already sent, so the only honest signal left is
                # to cut the connection instead of ending the body cleanly.
                log.warning("route %s: upstream %s broke off mid-response: %r", self._route.name, url, e)
                resp.force_close()
                if request.transport is not None:
                    request.transport.close()
                return resp
            await resp.write_eof()
            return resp
        finally:
            upstream_resp.release()

    async def _websocket(self, request: web.Request, match: Match[Handler], upstream: URL) -> web.StreamResponse:
        url = self._upstream_url(request, match, upstream)
        url = url.with_scheme("wss" if url.scheme == "https" else "ws")
        headers = self._request_headers(request)
        for name in WEBSOCKET_HANDSHAKE:
            headers.popall(name, None)
        protocols = [
            p.strip() for p in request.headers.get("Sec-WebSocket-Protocol", "").split(",") if p.strip()
        ]
        try:
            async with asyncio.timeout(self._target.timeout):  # bounds the handshake only
                upstream_ws = await self._session.ws_connect(
                    url, headers=headers, protocols=protocols, max_msg_size=0,
                    timeout=aiohttp.ClientWSTimeout(ws_receive=None, ws_close=10.0),
                )
        except aiohttp.ClientConnectorError:
            raise
        except TimeoutError:
            raise web.HTTPGatewayTimeout(text="504 Gateway Timeout\n") from None
        except aiohttp.WSServerHandshakeError as e:
            raise web.HTTPBadGateway(text=f"502 Bad Gateway: upstream refused the WebSocket ({e.status})\n") from None
        except (aiohttp.ClientError, TimeoutError) as e:
            log.warning("route %s: WebSocket to %s failed: %r", self._route.name, url, e)
            raise web.HTTPBadGateway(text="502 Bad Gateway\n") from None

        client_ws = web.WebSocketResponse(
            protocols=[upstream_ws.protocol] if upstream_ws.protocol else (), max_msg_size=0
        )
        try:
            await client_ws.prepare(request)
            pumps = [
                asyncio.create_task(_pump(client_ws, upstream_ws)),
                asyncio.create_task(_pump(upstream_ws, client_ws)),
            ]
            try:
                await asyncio.wait(pumps, return_when=asyncio.FIRST_COMPLETED)
            finally:
                for task in pumps:
                    task.cancel()
                await asyncio.gather(*pumps, return_exceptions=True)
        finally:
            await upstream_ws.close()
            await client_ws.close()
        return client_ws

    def _upstream_url(self, request: web.Request, match: Match[Handler], upstream: URL) -> URL:
        # Work on the raw (still percent-encoded) path so encoded characters
        # such as %2F reach the upstream exactly as the client sent them.
        raw_path, _, raw_query = request.raw_path.partition("?")
        prefix = self._route.path
        if not self._target.strip_prefix or prefix == "/":
            forwarded = raw_path
        elif raw_path == prefix or raw_path.startswith(prefix + "/"):
            forwarded = raw_path[len(prefix):]
        else:  # the prefix itself was percent-encoded by the client
            forwarded = URL.build(path=match.remainder).raw_path
        path = upstream.raw_path.rstrip("/") + (forwarded or "/")
        query = f"?{raw_query}" if raw_query else ""
        return URL(f"{upstream.origin()}{path}{query}", encoded=True)

    def _request_headers(self, request: web.Request) -> CIMultiDict[str]:
        headers = _strip_hop_by_hop(request.headers)
        if not self._target.preserve_host:
            headers.popall("Host", None)  # aiohttp fills it in from the upstream URL
        forwarded_for = request.headers.get("X-Forwarded-For")
        if request.remote:
            headers["X-Forwarded-For"] = f"{forwarded_for}, {request.remote}" if forwarded_for else request.remote
        headers["X-Forwarded-Proto"] = request.scheme
        headers["X-Forwarded-Host"] = request.host
        if self._target.strip_prefix and self._route.path != "/":
            headers["X-Forwarded-Prefix"] = self._route.path
        for name, value in self._target.request_headers:
            headers[name] = value
        return headers


class StaticHandler:
    def __init__(self, target: StaticTarget) -> None:
        self._target = target

    async def __call__(self, request: web.Request, match: Match[Handler]) -> web.StreamResponse:
        if request.method not in ("GET", "HEAD"):
            raise web.HTTPMethodNotAllowed(request.method, ["GET", "HEAD"])
        relative = match.remainder
        root = self._target.root
        file = (root / relative.lstrip("/")).resolve()
        if not file.is_relative_to(root):
            raise web.HTTPNotFound()
        if file.is_dir():
            if not request.path.endswith("/"):
                # /docs -> /docs/ so relative links inside the page resolve correctly
                raw_path, sep, raw_query = request.raw_path.partition("?")
                raise web.HTTPMovedPermanently(f"{raw_path}/{sep}{raw_query}")
            file = file / self._target.index
        if file.is_file():
            return web.FileResponse(file)
        if self._target.spa:
            index = root / self._target.index
            if index.is_file():
                return web.FileResponse(index)
        raise web.HTTPNotFound()


class RedirectHandler:
    def __init__(self, target: RedirectTarget) -> None:
        self._target = target

    async def __call__(self, request: web.Request, match: Match[Handler]) -> web.StreamResponse:
        location = self._target.location
        if self._target.keep_path:
            location = location.rstrip("/") + match.remainder
            if request.query_string:
                location += f"?{request.query_string}"
        return web.Response(status=self._target.status, headers={"Location": location or "/"})


class RespondHandler:
    def __init__(self, target: RespondTarget) -> None:
        self._target = target
        content_type = target.content_type
        if content_type.startswith("text/") and "charset" not in content_type:
            content_type += "; charset=utf-8"
        self._content_type = content_type
        self._body = target.body.encode()

    async def __call__(self, request: web.Request, match: Match[Handler]) -> web.StreamResponse:
        return web.Response(status=self._target.status, body=self._body, headers={"Content-Type": self._content_type})


# ---------- helpers ----------

def _is_websocket(request: web.Request) -> bool:
    return request.headers.get("Upgrade", "").lower() == "websocket"


def _strip_hop_by_hop(headers: MultiMapping[str]) -> CIMultiDict[str]:
    listed = {
        token.strip().lower()
        for value in headers.getall("Connection", [])
        for token in value.split(",")
    }
    return CIMultiDict(
        (name, value) for name, value in headers.items()
        if name.lower() not in HOP_BY_HOP and name.lower() not in listed
    )


async def _pump(src: web.WebSocketResponse | aiohttp.ClientWebSocketResponse,
                dst: web.WebSocketResponse | aiohttp.ClientWebSocketResponse) -> None:
    async for msg in src:
        if msg.type == WSMsgType.TEXT:
            await dst.send_str(msg.data)
        elif msg.type == WSMsgType.BINARY:
            await dst.send_bytes(msg.data)
        elif msg.type == WSMsgType.ERROR:
            break
    await dst.close(code=src.close_code or aiohttp.WSCloseCode.OK)
