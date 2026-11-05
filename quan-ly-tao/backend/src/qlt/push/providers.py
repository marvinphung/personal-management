import asyncio
import time
from pathlib import Path

import httpx
import jwt
from google.auth.transport.requests import Request
from google.oauth2 import service_account

from qlt.config import get_settings


class InvalidDeviceToken(Exception):
    pass


def validate_push_configuration():
    settings = get_settings()
    if settings.apns_enabled and not all((settings.apns_key_id, settings.apns_team_id,
            settings.apns_topic, settings.apns_private_key_file)):
        raise RuntimeError("APNs enabled but key ID, team ID, topic or key file missing")
    if settings.fcm_enabled and not all((settings.fcm_project_id, settings.fcm_service_account_file)):
        raise RuntimeError("FCM enabled but project ID or service account file missing")


async def send_apns(token: str, environment: str, revision: int, pending_count: int):
    settings = get_settings()
    validate_push_configuration()
    key = Path(settings.apns_private_key_file).read_text()
    provider_token = jwt.encode(
        {"iss": settings.apns_team_id, "iat": int(time.time())}, key,
        algorithm="ES256", headers={"kid": settings.apns_key_id},
    )
    host = "api.sandbox.push.apple.com" if environment == "sandbox" else "api.push.apple.com"
    async with httpx.AsyncClient(http2=True, timeout=10) as client:
        response = await client.post(f"https://{host}/3/device/{token}",
            headers={"authorization": f"bearer {provider_token}", "apns-topic": settings.apns_topic,
                "apns-push-type": "background", "apns-priority": "5", "apns-collapse-id": "qlt-inbox"},
            json={"aps": {"content-available": 1}, "inbox_revision": revision,
                  "pending_count": pending_count})
    if response.status_code == 410:
        raise InvalidDeviceToken()
    if response.status_code != 200:
        raise RuntimeError(f"APNs delivery failed (HTTP {response.status_code})")


def fcm_access_token():
    settings = get_settings()
    credentials = service_account.Credentials.from_service_account_file(
        settings.fcm_service_account_file,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"],
    )
    credentials.refresh(Request())
    return credentials.token


async def send_fcm(token: str, revision: int, pending_count: int):
    settings = get_settings()
    validate_push_configuration()
    access_token = await asyncio.to_thread(fcm_access_token)
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(
            f"https://fcm.googleapis.com/v1/projects/{settings.fcm_project_id}/messages:send",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"message": {"token": token,
                "data": {"inbox_revision": str(revision), "pending_count": str(pending_count)},
                "android": {"priority": "normal", "collapse_key": "qlt-inbox"}}},
        )
    if response.status_code == 404:
        error = response.json().get("error", {})
        if any(d.get("errorCode") == "UNREGISTERED" for d in error.get("details", [])):
            raise InvalidDeviceToken()
    if response.status_code != 200:
        raise RuntimeError(f"FCM delivery failed (HTTP {response.status_code})")
