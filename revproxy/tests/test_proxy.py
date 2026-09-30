"""End-to-end: a real upstream, a real ProxyServer on a free port, real HTTP."""
import asyncio
import json
import shutil
import socket
import ssl
import subprocess
from pathlib import Path

import aiohttp
import pytest
from aiohttp import web
from yarl import URL

from revproxy.server import ProxyServer


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture
async def upstream(aiohttp_server):
    async def echo(request: web.Request) -> web.Response:
        body = await request.read()
        return web.json_response({
            "path": request.raw_path,
            "method": request.method,
            "body": body.decode(),
            "headers": dict(request.headers),
        }, headers={"Set-Cookie": "a=1", "X-Upstream": "yes"})

    async def stream(request: web.Request) -> web.StreamResponse:
        resp = web.StreamResponse()
        await resp.prepare(request)
        for i in range(3):
            await resp.write(f"chunk{i}\n".encode())
        return resp

    async def ws(request: web.Request) -> web.WebSocketResponse:
        sock = web.WebSocketResponse(protocols=["chat"])
        await sock.prepare(request)
        async for msg in sock:
            if msg.type == aiohttp.WSMsgType.TEXT:
                await sock.send_str(f"echo:{msg.data}")
            elif msg.type == aiohttp.WSMsgType.BINARY:
                await sock.send_bytes(msg.data[::-1])
        return sock

    app = web.Application()
    app.router.add_get("/stream", stream)
    app.router.add_get("/ws", ws)
    app.router.add_route("*", "/{tail:.*}", echo)
    return await aiohttp_server(app)


@pytest.fixture
def site(tmp_path) -> Path:
    root = tmp_path / "public"
    (root / "docs").mkdir(parents=True)
    (root / "index.html").write_text("home")
    (root / "docs" / "index.html").write_text("docs")
    (root / "app.js").write_text("js")
    (tmp_path / "secret.txt").write_text("secret")
    return root


class Proxy:
    def __init__(self, tmp_path: Path) -> None:
        self.port = free_port()
        self.config = tmp_path / "revproxy.toml"
        self.server: ProxyServer | None = None
        self.task: asyncio.Task | None = None
        self.session = aiohttp.ClientSession(auto_decompress=False)

    def write(self, routes: str) -> None:
        self.config.write_text(f"[[listeners]]\nhost = \"127.0.0.1\"\nport = {self.port}\n\n{routes}")

    async def start(self, routes: str) -> None:
        self.write(routes)
        self.server = ProxyServer(self.config)
        self.task = asyncio.create_task(self.server.serve_forever())
        for _ in range(100):
            if self.server.config is not None and self.server._sites:
                return
            await asyncio.sleep(0.02)
        raise RuntimeError("proxy did not start")

    def url(self, path: str) -> URL:
        # encoded=True sends the path exactly as written, dot segments included
        return URL(f"http://127.0.0.1:{self.port}{path}", encoded=True)

    async def get(self, path: str, **kwargs) -> tuple[int, str, aiohttp.ClientResponse]:
        async with self.session.get(self.url(path), allow_redirects=False, **kwargs) as resp:
            return resp.status, await resp.text(), resp

    async def close(self) -> None:
        await self.session.close()
        if self.task:
            self.server.stop()
            await self.task


@pytest.fixture
async def proxy(tmp_path):
    p = Proxy(tmp_path)
    yield p
    await p.close()


async def test_proxy_forwards_request(proxy, upstream):
    await proxy.start(f'[[routes]]\npath = "/api"\nproxy = "{upstream.make_url("/")}"\n'
                      'request_headers = { X-Extra = "1" }\n')
    async with proxy.session.post(proxy.url("/api/users?q=a%20b"), data="hello",
                                  headers={"X-Forwarded-For": "10.0.0.1", "Connection": "keep-alive, X-Drop",
                                           "X-Drop": "gone"}) as resp:
        assert resp.status == 200
        assert resp.headers["X-Upstream"] == "yes"
        assert resp.headers.getall("Set-Cookie") == ["a=1"]
        data = await resp.json()
    assert data["path"] == "/api/users?q=a%20b"  # prefix kept by default, query untouched
    assert data["method"] == "POST" and data["body"] == "hello"
    headers = data["headers"]
    assert headers["X-Forwarded-For"] == "10.0.0.1, 127.0.0.1"
    assert headers["X-Forwarded-Proto"] == "http"
    assert headers["X-Forwarded-Host"] == f"127.0.0.1:{proxy.port}"
    assert headers["Host"] == f"{upstream.host}:{upstream.port}"
    assert headers["X-Extra"] == "1"
    assert "X-Drop" not in headers  # listed in Connection, so hop-by-hop


async def test_strip_prefix_and_upstream_base_path(proxy, upstream):
    await proxy.start(f'[[routes]]\npath = "/api"\nproxy = "{upstream.make_url("/base/")}"\n'
                      "strip_prefix = true\npreserve_host = true\n")
    _, body, _ = await proxy.get("/api/a%2Fb")
    data = json.loads(body)
    assert data["path"] == "/base/a%2Fb"  # encoded slash preserved
    assert data["headers"]["X-Forwarded-Prefix"] == "/api"
    assert data["headers"]["Host"] == f"127.0.0.1:{proxy.port}"


async def test_streaming_response(proxy, upstream):
    await proxy.start(f'[[routes]]\nproxy = "{upstream.make_url("/")}"\n')
    status, body, _ = await proxy.get("/stream")
    assert status == 200 and body == "chunk0\nchunk1\nchunk2\n"


async def test_failover_and_bad_gateway(proxy, upstream):
    dead = f"http://127.0.0.1:{free_port()}"
    await proxy.start(f'[[routes]]\npath = "/lb"\nproxy = ["{dead}", "{upstream.make_url("/")}"]\n'
                      f'[[routes]]\npath = "/dead"\nproxy = "{dead}"\n')
    for _ in range(3):
        status, _, _ = await proxy.get("/lb/x")
        assert status == 200
    status, _, _ = await proxy.get("/dead")
    assert status == 502


async def test_gateway_timeout(proxy, aiohttp_server):
    async def slow(request):
        await asyncio.sleep(2)
        return web.Response(text="late")
    app = web.Application()
    app.router.add_get("/", slow)
    slow_server = await aiohttp_server(app)
    await proxy.start(f'[[routes]]\nproxy = "{slow_server.make_url("/")}"\ntimeout = 0.2\n')
    status, _, _ = await proxy.get("/")
    assert status == 504


async def test_websocket(proxy, upstream):
    await proxy.start(f'[[routes]]\nproxy = "{upstream.make_url("/")}"\n')
    async with proxy.session.ws_connect(proxy.url("/ws"), protocols=["chat"]) as ws:
        assert ws.protocol == "chat"
        await ws.send_str("hi")
        assert (await ws.receive_str()) == "echo:hi"
        await ws.send_bytes(b"abc")
        assert (await ws.receive_bytes()) == b"cba"


async def test_static(proxy, site):
    await proxy.start(f'[[routes]]\npath = "/site"\nstatic = "{site}"\n'
                      'response_headers = { Cache-Control = "no-cache" }\n')
    status, body, resp = await proxy.get("/site/")
    assert (status, body) == (200, "home")
    assert resp.headers["Cache-Control"] == "no-cache"
    assert (await proxy.get("/site/app.js"))[:2] == (200, "js")
    status, _, resp = await proxy.get("/site/docs")
    assert status == 301 and resp.headers["Location"] == "/site/docs/"
    assert (await proxy.get("/site/docs/"))[:2] == (200, "docs")
    status, _, resp = await proxy.get("/site")
    assert status == 301 and resp.headers["Location"] == "/site/"
    assert (await proxy.get("/site/missing"))[0] == 404
    assert (await proxy.get("/site/../secret.txt"))[0] == 400
    assert (await proxy.get("/site/%2e%2e/secret.txt"))[0] == 400


async def test_spa_fallback(proxy, site):
    await proxy.start(f'[[routes]]\nstatic = "{site}"\nspa = true\n')
    assert (await proxy.get("/some/client/route"))[:2] == (200, "home")
    assert (await proxy.get("/app.js"))[:2] == (200, "js")


async def test_redirect_and_respond(proxy):
    await proxy.start('[[routes]]\npath = "/old"\nredirect = "https://example.com/new"\nstatus = 308\nkeep_path = true\n'
                      '[[routes]]\npath = "/healthz"\nrespond = "ok"\n'
                      '[[routes]]\nhost = "only.test"\nrespond = "host route"\n')
    status, _, resp = await proxy.get("/old/a/b?x=1")
    assert status == 308 and resp.headers["Location"] == "https://example.com/new/a/b?x=1"
    status, body, resp = await proxy.get("/healthz")
    assert (status, body) == (200, "ok")
    assert resp.headers["Content-Type"] == "text/plain; charset=utf-8"
    assert (await proxy.get("/", headers={"Host": "only.test"}))[1] == "host route"
    assert (await proxy.get("/nothing"))[0] == 404


async def wait_for(predicate, timeout: float = 5.0) -> None:
    deadline = asyncio.get_running_loop().time() + timeout
    while not await predicate():
        if asyncio.get_running_loop().time() > deadline:
            raise AssertionError("condition not met in time")
        await asyncio.sleep(0.05)


async def test_reload_on_file_change(proxy):
    await proxy.start('[[routes]]\nrespond = "one"\n')
    assert (await proxy.get("/"))[1] == "one"
    await asyncio.sleep(0.3)  # let the watcher settle

    proxy.write('[[routes]]\nrespond = "two"\n')
    async def says_two():
        return (await proxy.get("/"))[1] == "two"
    await wait_for(says_two)

    # A broken edit is rejected and the last good config keeps serving.
    proxy.config.write_text("[[routes]\n")
    await asyncio.sleep(1.0)
    assert (await proxy.get("/"))[1] == "two"

    # Atomic save (write elsewhere, rename over) as many editors do.
    tmp = proxy.config.with_suffix(".tmp")
    tmp.write_text(proxy.config.read_text())
    proxy.write('[[routes]]\nrespond = "three"\n')
    tmp.write_text(proxy.config.read_text())
    tmp.replace(proxy.config)
    async def says_three():
        return (await proxy.get("/"))[1] == "three"
    await wait_for(says_three)


async def test_reload_moves_listener(proxy):
    await proxy.start('[[routes]]\nrespond = "hi"\n')
    old_port = proxy.port
    proxy.port = free_port()
    proxy.write('[[routes]]\nrespond = "moved"\n')
    assert await proxy.server.reload()
    assert (await proxy.get("/"))[1] == "moved"
    with pytest.raises(aiohttp.ClientConnectorError):
        await proxy.session.get(f"http://127.0.0.1:{old_port}/")


async def test_reload_skips_unchanged_content(proxy):
    await proxy.start('[[routes]]\nrespond = "hi"\n')
    proxy.config.touch()
    assert not await proxy.server.reload()
    assert await proxy.server.reload(force=True)


@pytest.mark.skipif(shutil.which("openssl") is None, reason="needs the openssl CLI")
async def test_tls_listener_and_cert_reload(proxy, tmp_path):
    def make_cert(name: str) -> None:
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                        "-subj", f"/CN={name}", "-keyout", str(tmp_path / "key.pem"),
                        "-out", str(tmp_path / "cert.pem")], check=True, capture_output=True)

    async def served_cert() -> str:
        # a fresh handshake each time, so a pooled connection cannot hide the swap
        return await asyncio.to_thread(ssl.get_server_certificate, ("127.0.0.1", tls_port))

    make_cert("first")
    tls_port = free_port()
    await proxy.start(f'[[listeners]]\nhost = "127.0.0.1"\nport = {tls_port}\n'
                      'tls_cert = "cert.pem"\ntls_key = "key.pem"\n[[routes]]\nrespond = "secure"\n')
    async with proxy.session.get(f"https://127.0.0.1:{tls_port}/", ssl=False) as resp:
        assert await resp.text() == "secure"
    first = await served_cert()

    make_cert("second")  # a renewal: same paths, new contents, picked up by the watcher
    async def cert_changed():
        return await served_cert() != first
    await wait_for(cert_changed)
