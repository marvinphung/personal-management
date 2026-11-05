"""Native launchd entry point: load private .env without shell-evaluating secrets."""

import os
import shutil
from pathlib import Path

from qlt.config import get_settings


def main():
    settings = get_settings()
    if not settings.nats_user or not settings.nats_password:
        raise RuntimeError("Native broker requires NATS_USER and NATS_PASSWORD in private .env")
    binary = shutil.which("nats-server")
    if not binary:
        raise RuntimeError("nats-server not found on launchd PATH")
    root = Path(__file__).resolve().parents[3].parent
    # src/qlt/messaging/run_nats.py -> backend -> repository root
    configured_store = getattr(settings, "nats_store_dir", None)
    store = Path(configured_store) if configured_store else root / "data" / "jetstream"
    store.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env.update(
        NATS_HOST=getattr(settings, "nats_host", "127.0.0.1"),
        NATS_MONITOR_LISTEN=getattr(settings, "nats_monitor_listen", "127.0.0.1:8222"),
        NATS_STORE_DIR=str(store),
        NATS_USER=settings.nats_user,
        NATS_PASSWORD=settings.nats_password,
    )
    os.execvpe(binary, [binary, "-c", str(root / "deploy/nats/nats.conf")], env)


if __name__ == "__main__":
    main()
