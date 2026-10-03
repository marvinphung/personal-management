import os
import pytest
from fastapi.testclient import TestClient

# Ensure test environment is explicitly set before importing app or config
os.environ["ENVIRONMENT"] = "test"
if not os.environ.get("DATABASE_URL"):
    os.environ["DATABASE_URL"] = "postgresql://test_user:test_password@localhost:5433/qlt_test?sslmode=disable"
os.environ["DATABASE_SCHEMA"] = "qlt"

from qlt.config import get_settings  # noqa: E402
from qlt.main import app  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def guard_test_environment():
    settings = get_settings()
    settings.assert_test_database()


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client
