from types import SimpleNamespace
from unittest.mock import AsyncMock

import httpx
import pytest

from qlt.push import providers


def provider_settings():
    return SimpleNamespace(apns_enabled=True, fcm_enabled=True, apns_key_id="key-id",
        apns_team_id="team-id", apns_topic="app.quanlytao.user", apns_private_key_file="key.p8",
        fcm_project_id="project", fcm_service_account_file="service-account.json")


async def test_apns_background_headers_and_count_only(monkeypatch):
    monkeypatch.setattr(providers, "get_settings", provider_settings)
    monkeypatch.setattr(providers.Path, "read_text", lambda _: "private-key")
    monkeypatch.setattr(providers.jwt, "encode", lambda *args, **kwargs: "signed-jwt")
    post = AsyncMock(return_value=httpx.Response(200))
    monkeypatch.setattr(httpx.AsyncClient, "post", post)
    await providers.send_apns("device-token", "sandbox", 7, 2)
    args, kwargs = post.call_args
    assert args[0] == "https://api.sandbox.push.apple.com/3/device/device-token"
    assert kwargs["headers"]["apns-push-type"] == "background"
    assert kwargs["headers"]["apns-priority"] == "5"
    assert kwargs["json"] == {"aps": {"content-available": 1}, "inbox_revision": 7, "pending_count": 2}


async def test_fcm_uses_v1_and_string_metadata(monkeypatch):
    monkeypatch.setattr(providers, "get_settings", provider_settings)
    monkeypatch.setattr(providers, "fcm_access_token", lambda: "oauth-token")
    post = AsyncMock(return_value=httpx.Response(200))
    monkeypatch.setattr(httpx.AsyncClient, "post", post)
    await providers.send_fcm("device-token", 8, 3)
    args, kwargs = post.call_args
    assert args[0] == "https://fcm.googleapis.com/v1/projects/project/messages:send"
    assert kwargs["headers"]["Authorization"] == "Bearer oauth-token"
    assert kwargs["json"]["message"]["data"] == {"inbox_revision": "8", "pending_count": "3"}


async def test_provider_failure_is_retryable_and_does_not_log_token(monkeypatch):
    monkeypatch.setattr(providers, "get_settings", provider_settings)
    monkeypatch.setattr(providers, "fcm_access_token", lambda: "secret-oauth")
    monkeypatch.setattr(httpx.AsyncClient, "post", AsyncMock(return_value=httpx.Response(503)))
    with pytest.raises(RuntimeError, match="HTTP 503") as exc:
        await providers.send_fcm("secret-device-token", 1, 1)
    assert "secret" not in str(exc.value)


def test_enabled_provider_requires_credentials(monkeypatch):
    settings = provider_settings()
    settings.apns_key_id = None
    monkeypatch.setattr(providers, "get_settings", lambda: settings)
    with pytest.raises(RuntimeError, match="APNs enabled"):
        providers.validate_push_configuration()
