import logging
import uuid
from typing import Literal

from pydantic import BaseModel, Field

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.worker import register_push_dispatcher
from qlt.push.providers import InvalidDeviceToken, send_apns, send_fcm, validate_push_configuration

logger = logging.getLogger(__name__)


class PushRegistrationRequest(BaseModel):
    platform: Literal["ios", "android"]
    device_id: str = Field(min_length=1, max_length=200)
    token: str = Field(min_length=1, max_length=4096)
    environment: Literal["production", "sandbox"] = "production"


async def register_push_device(
    user_id: uuid.UUID,
    platform: str,
    device_id: str,
    token: str,
    environment: str = "production",
) -> None:
    settings = get_settings()
    schema = settings.database_schema

    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(
                    f"""
                    INSERT INTO {schema}.push_devices (
                        user_id, platform, device_id, token, environment, last_seen_at
                    ) VALUES (%s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (user_id, device_id) DO UPDATE
                    SET token = EXCLUDED.token,
                        platform = EXCLUDED.platform,
                        environment = EXCLUDED.environment,
                        last_seen_at = NOW();
                    """,
                    (str(user_id), platform.lower(), device_id, token, environment),
                )


async def revoke_push_device(
    user_id: uuid.UUID,
    device_id: str,
) -> None:
    settings = get_settings()
    schema = settings.database_schema

    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(
                    f"""
                    DELETE FROM {schema}.push_devices
                    WHERE user_id = %s AND device_id = %s;
                    """,
                    (str(user_id), device_id),
                )


async def dispatch_push_refresh(
    user_id: uuid.UUID,
    inbox_revision: int,
) -> None:
    """Dispatches a silent/background push signal containing only latest count/revision

    to all registered devices for this user. Honest adapter: reports disabled if credentials
    are not configured.
    """
    settings = get_settings()
    schema = settings.database_schema

    if not settings.apns_enabled and not settings.fcm_enabled:
        logger.info("Push disabled: no provider delivery attempted")
        return
    validate_push_configuration()

    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(
                    f"""
                    SELECT platform, device_id, token, environment
                    FROM {schema}.push_devices
                    WHERE user_id = %s;
                    """,
                    (str(user_id),),
                )
                devices = await cur.fetchall()
                await cur.execute(
                    f"""SELECT r.inbox_revision,
                    (SELECT COUNT(*) FROM {schema}.bank_event_receipts b
                     WHERE b.user_id=r.user_id AND b.state='pending') AS pending_count
                    FROM {schema}.user_revisions r JOIN {schema}.users u ON u.id=r.user_id
                    WHERE r.user_id=%s AND u.status='active'""", (str(user_id),),
                )
                current = await cur.fetchone()

    if not devices or not current:
        return

    failures = []
    for dev in devices:
        try:
            if dev["platform"] == "ios" and settings.apns_enabled:
                await send_apns(dev["token"], dev["environment"], current["inbox_revision"], current["pending_count"])
            elif dev["platform"] == "android" and settings.fcm_enabled:
                await send_fcm(dev["token"], current["inbox_revision"], current["pending_count"])
            else:
                logger.info("Push provider disabled for platform %s", dev["platform"])
        except InvalidDeviceToken:
            await revoke_push_device(user_id, dev["device_id"])
        except Exception as exc:
            failures.append(type(exc).__name__)
    if failures:
        raise RuntimeError("Push delivery deferred; provider failures: " + ",".join(failures))


# Register push dispatcher with outbox worker
register_push_dispatcher(dispatch_push_refresh)
