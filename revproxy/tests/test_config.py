from pathlib import Path

import pytest

from revproxy.config import ConfigError, ProxyTarget, StaticTarget, load_config


def write(tmp_path: Path, text: str) -> Path:
    path = tmp_path / "revproxy.toml"
    path.write_text(text)
    return path


def test_defaults(tmp_path):
    config = load_config(write(tmp_path, '[[routes]]\nproxy = "http://127.0.0.1:3000"\n'))
    assert [(lst.host, lst.port) for lst in config.listeners] == [("0.0.0.0", 8080)]
    route = config.routes[0]
    assert route.path == "/" and route.hosts == ()
    assert isinstance(route.target, ProxyTarget)
    assert route.target.timeout == 60


def test_static_path_is_relative_to_config_file(tmp_path):
    (tmp_path / "www").mkdir()
    config = load_config(write(tmp_path, '[[routes]]\npath = "/site/"\nstatic = "www"\n'))
    route = config.routes[0]
    assert isinstance(route.target, StaticTarget)
    assert route.target.root == (tmp_path / "www").resolve()
    assert route.path == "/site"  # trailing slash dropped


def test_host_normalised(tmp_path):
    config = load_config(write(tmp_path, '[[routes]]\nhost = "App.Example.COM."\nrespond = "hi"\n'))
    assert config.routes[0].hosts == ("app.example.com",)


def test_tls_files_are_watched(tmp_path):
    config = load_config(write(tmp_path, '[[listeners]]\nport = 443\ntls_cert = "c.pem"\ntls_key = "k.pem"\n'))
    assert config.watched_files == {tmp_path / "revproxy.toml", tmp_path / "c.pem", tmp_path / "k.pem"}


@pytest.mark.parametrize("text, message", [
    ('[[routes]]\npath = "/"\n', "exactly one of"),
    ('[[routes]]\nproxy = "x"\nrespond = "y"\n', "exactly one of"),
    ('[[routes]]\nproxy = "ftp://host"\n', "http:// or https://"),
    ('[[routes]]\nproxy = "http://h"\nstrip_prefx = true\n', "unknown key(s) strip_prefx"),
    ('[[routes]]\nrespond = "x"\npath = "api"\n', "must start with '/'"),
    ('[[routes]]\nrespond = "x"\nhost = "a.*.com"\n', "wildcard"),
    ('[[routes]]\nstatic = "missing"\n', "does not exist"),
    ('[[routes]]\nredirect = "/x"\nstatus = 200\n', "redirect status"),
    ('[[routes]]\nproxy = "http://h"\ntimeout = true\n', "timeout must be a number"),
    ('[[listeners]]\nport = 70000\n', "port must be"),
    ('[[listeners]]\nport = 1\ntls_cert = "c"\n', "set together"),
    ('[[listeners]]\nport = 1\n[[listeners]]\nport = 1\n', "same host and port"),
    ('[server]\nlog_level = "loud"\n', "log_level"),
    ('routes = 1\n', "array of tables"),
    ('[[routes]\n', "invalid TOML"),
])
def test_invalid(tmp_path, text, message):
    with pytest.raises(ConfigError) as info:
        load_config(write(tmp_path, text))
    assert message in str(info.value)


def test_missing_file(tmp_path):
    with pytest.raises(ConfigError, match="cannot read"):
        load_config(tmp_path / "nope.toml")
