import logging
import uuid

from nats.js import JetStreamContext
from nats.js.api import DiscardPolicy, RetentionPolicy, StorageType, StreamConfig, StreamInfo
from nats.js.errors import NotFoundError

from qlt.config import get_settings

logger = logging.getLogger(__name__)


def build_event_subject(user_id: uuid.UUID, event_id: uuid.UUID) -> str:
    """Builds the NATS subject for a pending bank event."""
    settings = get_settings()
    prefix = settings.get_subject_prefix()
    return f"{prefix}.{user_id}.{event_id}"


def build_event_msg_id(event_id: uuid.UUID) -> str:
    """Builds the Nats-Msg-Id for deduplication."""
    return f"qlt-event-{event_id}"


async def ensure_stream(js: JetStreamContext) -> StreamInfo:
    """Idempotently ensures the QLT pending bank events stream exists with exact configuration.

    Raises RuntimeError if an incompatible stream configuration already exists,
    preventing data loss.
    """
    settings = get_settings()
    stream_name = settings.get_stream_name()
    subject_pattern = f"{settings.get_subject_prefix()}.>"

    storage_type = (
        StorageType.MEMORY
        if settings.nats_storage_type.lower() == "memory"
        else StorageType.FILE
    )

    desired_config = StreamConfig(
        name=stream_name,
        subjects=[subject_pattern],
        retention=RetentionPolicy.LIMITS,
        storage=storage_type,
        discard=DiscardPolicy.NEW,
        max_bytes=settings.nats_max_bytes,
        max_msg_size=settings.nats_max_msg_size,
        duplicate_window=float(settings.nats_duplicate_window_seconds),
        num_replicas=1,
        max_age=0,
        max_msgs_per_subject=1,
        discard_new_per_subject=True,
    )

    try:
        existing = await js.stream_info(stream_name)
        cfg = existing.config

        # Validate critical properties for incompatibility
        if cfg.retention != desired_config.retention:
            raise RuntimeError(
                f"Stream {stream_name} has incompatible retention policy: "
                f"expected {desired_config.retention}, found {cfg.retention}. "
                "Refusing to delete or recreate existing stream."
            )
        if cfg.storage != desired_config.storage:
            raise RuntimeError(
                f"Stream {stream_name} has incompatible storage type: "
                f"expected {desired_config.storage}, found {cfg.storage}. "
                "Refusing to delete or recreate existing stream."
            )
        if cfg.discard != desired_config.discard:
            raise RuntimeError(
                f"Stream {stream_name} has incompatible discard policy: "
                f"expected {desired_config.discard}, found {cfg.discard}. "
                "Refusing to delete or recreate existing stream."
            )

        if cfg.max_age or cfg.max_msgs not in (None, -1, 0):
            raise RuntimeError("Existing stream has expiry/eviction limits; reconcile before startup")
        if existing.state.bytes > settings.nats_max_bytes:
            raise RuntimeError("Refusing to shrink the stream below its stored payload size")
        # Update subjects and limits if safe
        info = await js.update_stream(desired_config)
        logger.info(f"JetStream stream '{stream_name}' validated and updated.")
        return info

    except NotFoundError:
        logger.info(f"Creating JetStream stream '{stream_name}' with pattern '{subject_pattern}'...")
        info = await js.add_stream(desired_config)
        logger.info(f"JetStream stream '{stream_name}' created successfully.")
        return info
