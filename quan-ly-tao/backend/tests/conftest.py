import os
import pytest
from fastapi.testclient import TestClient

# Ensure test environment is explicitly set before importing app or config
os.environ["ENVIRONMENT"] = "test"
if not os.environ.get("DATABASE_URL"):
    os.environ["DATABASE_URL"] = "postgresql://test_user:test_password@localhost:5433/qlt_test?sslmode=disable"
os.environ["DATABASE_SCHEMA"] = "qlt"
os.environ["NATS_STORAGE_TYPE"] = "memory"
os.environ["NATS_STREAM_PREFIX"] = "QLT_TEST"
os.environ.setdefault("NATS_URL", "nats://127.0.0.1:4222")
os.environ["NATS_USER"] = ""
os.environ["NATS_PASSWORD"] = ""
os.environ["APNS_ENABLED"] = "false"
os.environ["FCM_ENABLED"] = "false"

from qlt.config import get_settings  # noqa: E402
from qlt.main import app  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def guard_test_environment():
    settings = get_settings()
    settings.assert_test_database()
    settings.assert_test_nats()


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(autouse=True)
async def close_async_resources():
    yield
    from qlt.db import close_async_pool
    from qlt.messaging.client import close_nats
    await close_nats()
    await close_async_pool()
