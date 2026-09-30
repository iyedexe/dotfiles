# revproxy

A small reverse proxy in Python (aiohttp), managed with [uv]. It is configured
by one TOML file and **reloads itself when that file changes**. No restart is
needed and open connections are not dropped.

- **Proxy** to backend services over HTTP, streaming and **WebSockets**, with
  round-robin load balancing and failover across several upstreams.
- **Static** websites from a directory, with an optional single-page-app fallback.
- **Redirects** and fixed **responses** (health checks and similar).
- Routing by **host** (exact or `*.example.com`) and **path prefix**.
- **HTTPS** listeners. Certificate files are watched too, so a renewal is
  picked up without a restart.
- A broken edit is logged and ignored, and the last good config keeps serving.

[uv]: https://docs.astral.sh/uv/

## Run

```sh
cd revproxy
uv run revproxy -c examples/revproxy.toml          # http://localhost:8080
uv run revproxy --check -c examples/revproxy.toml  # validate and list the routes
```

To install the command globally: `uv tool install ./revproxy`, then run
`revproxy -c /path/to/revproxy.toml`.

A reload happens:
- when the config file or a TLS file it names is saved (only if its contents
  changed);
- on `SIGHUP` (`kill -HUP <pid>`), which always reloads.

`SIGINT` and `SIGTERM` shut it down cleanly.

## Config

[`examples/revproxy.toml`](examples/revproxy.toml) shows and explains every
option. In short:

```toml
[[listeners]]
port = 8080

[[routes]]                      # a service
path = "/api"
proxy = "http://127.0.0.1:3000"
strip_prefix = true             # /api/users -> /users

[[routes]]                      # a subdomain with two instances
host = "app.example.com"
proxy = ["http://127.0.0.1:5001", "http://127.0.0.1:5002"]

[[routes]]                      # a website
path = "/"
static = "public"
```

Each route sets exactly one of `proxy`, `static`, `redirect` or `respond`.
Routes are matched in this order: exact host, then wildcard host, then routes
with no host; within each group the longest path prefix wins; remaining ties
go to the route that comes first in the file. Unknown keys are errors, so a
typo is reported instead of silently ignored. Relative paths are relative to
the config file.

Proxied requests get `X-Forwarded-For`, `X-Forwarded-Proto` and
`X-Forwarded-Host` headers, plus `X-Forwarded-Prefix` when `strip_prefix` is
set. Bodies stream in both directions and are never buffered. Paths
containing `.` or `..` segments are rejected with 400, so the route that
matches and the path the upstream receives always agree.

## Notes

- Changing a listener's host or port on reload closes the old socket and
  opens the new one. Connections already open on the old socket finish
  normally.
- On Docker bind mounts or network filesystems where file events do not
  arrive, set `WATCHFILES_FORCE_POLLING=1`, or send `SIGHUP`.
- `timeout` is the longest the proxy waits for the upstream to send data. For
  long-polling or server-sent-event routes, raise it. WebSockets are not
  affected by it.

## Develop

```sh
uv run pytest
```

Layout: `config.py` parses and validates, `router.py` picks the route,
`handlers.py` has one handler per route kind, `server.py` owns the sockets,
the file watcher and the atomic reload.
