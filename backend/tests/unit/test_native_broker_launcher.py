from pathlib import Path
from types import SimpleNamespace

import pytest

from qlt.messaging import run_nats


def test_launcher_loads_private_config_and_execs_native_server(monkeypatch):
    monkeypatch.setattr(run_nats, "get_settings", lambda: SimpleNamespace(nats_user="test", nats_password="test-only"))
    monkeypatch.setattr(run_nats.shutil, "which", lambda _: "/opt/homebrew/bin/nats-server")
    monkeypatch.setattr(Path, "mkdir", lambda *args, **kwargs: None)
    captured = {}

    def fake_exec(binary, args, env):
        captured.update(binary=binary, args=args, env=env)

    monkeypatch.setattr(run_nats.os, "execvpe", fake_exec)
    run_nats.main()
    root = Path(__file__).resolve().parents[3]
    assert captured["args"] == ["/opt/homebrew/bin/nats-server", "-c", str(root / "deploy/nats/nats.conf")]
    assert captured["env"]["NATS_STORE_DIR"] == str(root / "data/jetstream")
    assert captured["env"]["NATS_PASSWORD"] == "test-only"
    assert captured["env"]["NATS_HOST"] == "127.0.0.1"


def test_launcher_rejects_missing_password(monkeypatch):
    monkeypatch.setattr(run_nats, "get_settings", lambda: SimpleNamespace(nats_user="test", nats_password=None))
    with pytest.raises(RuntimeError, match="NATS_USER and NATS_PASSWORD"):
        run_nats.main()
