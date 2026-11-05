import asyncio
import os
import shutil
import socket
import subprocess
from pathlib import Path

import nats
import pytest
from nats.js.api import DiscardPolicy, RetentionPolicy, StorageType, StreamConfig


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


async def test_production_config_persists_acknowledged_payload_after_crash(tmp_path):
    binary = shutil.which("nats-server")
    if not binary:
        pytest.skip("Native nats-server required for isolated disk/restart test")
    port, monitor = free_port(), free_port()
    config = Path(__file__).resolve().parents[3] / "deploy/nats/nats.conf"
    # Use the deployment config, private ports and test credentials/storage only.
    env = {"PATH": os.environ["PATH"], "NATS_HOST": "127.0.0.1",
        "NATS_MONITOR_LISTEN": f"127.0.0.1:{monitor}", "NATS_STORE_DIR": str(tmp_path / "store"),
        "NATS_USER": "test", "NATS_PASSWORD": "test-only"}
    log = (tmp_path / "broker.log").open("wb")
    process = None
    nc = None

    async def connect():
        async def ignore_error(_):
            pass
        for _ in range(60):
            try:
                return await nats.connect(f"nats://127.0.0.1:{port}", user="test", password="test-only",
                    max_reconnect_attempts=0, connect_timeout=0.2, error_cb=ignore_error)
            except Exception:
                await asyncio.sleep(0.05)
        raise AssertionError("Isolated broker failed to start")

    try:
        process = subprocess.Popen([binary, "-c", str(config), "-p", str(port)], env=env,
            stdout=log, stderr=log)
        nc = await connect()
        js = nc.jetstream()
        await js.add_stream(StreamConfig(name="QLT_TEST_DURABLE", subjects=["qlt.test.durable.>"],
            retention=RetentionPolicy.LIMITS, storage=StorageType.FILE, discard=DiscardPolicy.NEW,
            max_bytes=65536, max_msg_size=1024, max_msgs_per_subject=1, discard_new_per_subject=True))
        ack = await js.publish("qlt.test.durable.event", b"acknowledged-financial-payload")
        # Kill without graceful shutdown: PubAck must already be durable.
        process.kill()
        await asyncio.to_thread(process.wait, 5)
        await nc.close()
        nc = None
        process = subprocess.Popen([binary, "-c", str(config), "-p", str(port)], env=env,
            stdout=log, stderr=log)
        nc = await connect()
        msg = await nc.jetstream().get_msg("QLT_TEST_DURABLE", seq=ack.seq)
        assert msg.data == b"acknowledged-financial-payload"
    finally:
        if nc:
            await nc.close()
        if process and process.poll() is None:
            process.terminate()
            await asyncio.to_thread(process.wait, 5)
        log.close()
