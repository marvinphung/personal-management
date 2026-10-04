import asyncio
import logging
from typing import Optional

import nats
from nats.aio.client import Client as NATS
from nats.js import JetStreamContext

from qlt.config import get_settings

logger = logging.getLogger(__name__)

_nc: Optional[NATS] = None
_js: Optional[JetStreamContext] = None
_lock = asyncio.Lock()
_owner_loop = None


async def get_nats_client() -> NATS:
    global _nc, _js, _lock, _owner_loop
    current_loop = asyncio.get_running_loop()
    if _nc is not None:
        if _owner_loop is not current_loop or _nc.is_closed:
            _nc = None
            _js = None

    if _nc is not None and not _nc.is_closed:
        return _nc

    if _owner_loop is not current_loop:
        _lock = asyncio.Lock()
        _owner_loop = current_loop

    async with _lock:
        if _nc is not None:
            if _owner_loop is not current_loop or _nc.is_closed:
                _nc = None
                _js = None
        if _nc is not None and not _nc.is_closed:
            return _nc

        settings = get_settings()
        connect_options = {
            "servers": [settings.nats_url],
            "max_reconnect_attempts": settings.nats_max_reconnect_attempts,
            "reconnect_time_wait": settings.nats_reconnect_time_wait_seconds,
            "name": f"qlt-backend-{settings.environment}",
        }

        if settings.nats_user and settings.nats_password:
            connect_options["user"] = settings.nats_user
            connect_options["password"] = settings.nats_password
        elif settings.nats_credentials_file:
            connect_options["user_credentials"] = settings.nats_credentials_file

        async def error_cb(e):
            logger.error(f"NATS error: {e}")

        async def disconnected_cb():
            logger.warning("NATS disconnected")

        async def reconnected_cb():
            logger.info("NATS reconnected")

        connect_options["error_cb"] = error_cb
        connect_options["disconnected_cb"] = disconnected_cb
        connect_options["reconnected_cb"] = reconnected_cb

        try:
            _nc = await nats.connect(**connect_options)
            logger.info("Connected to NATS")
            return _nc
        except Exception as e:
            logger.error("Failed to connect to NATS (%s)", type(e).__name__)
            raise


async def get_jetstream() -> JetStreamContext:
    global _js
    nc = await get_nats_client()
    if _js is not None and getattr(_js, "_nc", None) is nc:
        return _js

    settings = get_settings()
    _js = nc.jetstream(timeout=settings.nats_publish_timeout_seconds)
    return _js


async def close_nats() -> None:
    global _nc, _js
    async with _lock:
        if _nc is not None:
            try:
                if not _nc.is_closed:
                    try:
                        await asyncio.wait_for(_nc.drain(), timeout=0.2)
                    except Exception:
                        pass
                    try:
                        await _nc.close()
                    except Exception:
                        pass
                logger.info("NATS connection closed cleanly")
            except Exception as e:
                logger.warning(f"Error during NATS close: {e}")
            finally:
                _nc = None
                _js = None


async def check_nats_ready() -> bool:
    """Verifies that NATS is connected and JetStream is responsive."""
    try:
        nc = await get_nats_client()
        if not nc.is_connected:
            return False
        js = await get_jetstream()
        from nats.js.api import DiscardPolicy, RetentionPolicy, StorageType
        settings = get_settings()
        cfg = (await js.stream_info(settings.get_stream_name())).config
        return (cfg.retention == RetentionPolicy.LIMITS and cfg.discard == DiscardPolicy.NEW
            and cfg.storage == (StorageType.MEMORY if settings.nats_storage_type.lower() == "memory" else StorageType.FILE)
            and not cfg.max_age and cfg.max_msgs_per_subject == 1 and cfg.discard_new_per_subject)
    except Exception as e:
        logger.debug(f"NATS readiness check failed: {e}")
        return False
