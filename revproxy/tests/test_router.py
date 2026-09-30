import pytest

from revproxy.config import RespondTarget, Route
from revproxy.router import Router, normalize_host


def route(name: str, path: str = "/", hosts: tuple[str, ...] = ()) -> Route:
    return Route(name, hosts, path, RespondTarget(name, 200, "text/plain"), ())


def router(*routes: Route) -> Router[str]:
    return Router((r, r.name) for r in routes)


def test_longest_prefix_wins():
    r = router(route("root"), route("api", "/api"), route("v2", "/api/v2"))
    assert r.match("x", "/api/v2/users").handler == "v2"
    assert r.match("x", "/api/v1").handler == "api"
    assert r.match("x", "/other").handler == "root"


def test_prefix_matches_whole_segments():
    r = router(route("api", "/api"))
    assert r.match("x", "/api").remainder == ""
    assert r.match("x", "/api/").remainder == "/"
    assert r.match("x", "/api/a/b").remainder == "/a/b"
    assert r.match("x", "/apix") is None


def test_host_precedence_beats_path_length():
    r = router(route("any-long", "/deep/path"), route("wild", hosts=("*.example.com",)),
               route("exact", hosts=("app.example.com",)))
    assert r.match("app.example.com", "/deep/path").handler == "exact"
    assert r.match("other.example.com", "/deep/path").handler == "wild"
    assert r.match("example.com", "/deep/path").handler == "any-long"
    assert r.match("example.com", "/") is None


def test_ties_go_to_config_order():
    r = router(route("first", "/a"), route("second", "/a"))
    assert r.match("x", "/a").handler == "first"


def test_multiple_hosts_on_one_route():
    r = router(route("both", hosts=("a.test", "b.test")))
    assert r.match("a.test", "/").handler == "both"
    assert r.match("B.TEST:8080", "/").handler == "both"
    assert r.match("c.test", "/") is None


@pytest.mark.parametrize("raw, expected", [
    ("Example.com:8080", "example.com"),
    ("example.com.", "example.com"),
    ("[::1]:8080", "[::1]"),
    ("127.0.0.1", "127.0.0.1"),
])
def test_normalize_host(raw, expected):
    assert normalize_host(raw) == expected
