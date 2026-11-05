import asyncio
import logging
import uuid
from typing import Any, Callable, Optional

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.cleanup import delete_event_payload
from qlt.messaging.client import get_jetstream
from qlt.messaging.outbox import complete_outbox_job, fail_outbox_job, lease_outbox_jobs
from qlt.messaging.schemas import OutboxJobKind

logger = logging.getLogger(__name__)

# Hooks for realtime and push dispatchers (registered by J07 / J08)
_realtime_dispatcher: Optional[Callable[[uuid.UUID, int], Any]] = None
_push_dispatcher: Optional[Callable[[uuid.UUID, int], Any]] = None


def register_realtime_dispatcher(fn: Callable[[uuid.UUID, int], Any]) -> None:
    global _realtime_dispatcher
    _realtime_dispatcher = fn


def register_push_dispatcher(fn: Callable[[uuid.UUID, int], Any]) -> None:
    global _push_dispatcher
    _push_dispatcher = fn


async def process_outbox_batch(worker_id: str, batch_size: int = 50) -> int:
    """Claims and executes a batch of outbox jobs."""
    settings = get_settings()
    schema = settings.database_schema

    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                jobs = await lease_outbox_jobs(
                    cur=cur,
                    schema=schema,
                    worker_id=worker_id,
                    batch_size=batch_size,
                    lease_seconds=settings.outbox_worker_lease_seconds,
                )

    if not jobs:
        return 0

    js = None
    try:
        js = await get_jetstream()
    except Exception as e:
        logger.warning(f"Worker cannot connect to JetStream: {e}")

    for job in jobs:
        job_id = job["id"]
        kind = job["kind"]
        user_id = job["user_id"]
        inbox_rev = job.get("inbox_revision") or 0

        try:
            if kind == OutboxJobKind.PAYLOAD_CLEANUP.value:
                stream_name = job.get("stream_name")
                if stream_name and job.get("event_id"):
                    if not js:
                        raise RuntimeError("JetStream not available for payload cleanup")
                    await delete_event_payload(js, stream_name, user_id, job["event_id"])

            elif kind == OutboxJobKind.REALTIME_INVALIDATION.value:
                if not _realtime_dispatcher:
                    raise RuntimeError("Realtime dispatcher not registered")
                res = _realtime_dispatcher(user_id, inbox_rev)
                if asyncio.iscoroutine(res):
                    await res

            elif kind == OutboxJobKind.PUSH_REFRESH.value:
                if not _push_dispatcher:
                    raise RuntimeError("Push dispatcher not registered")
                res = _push_dispatcher(user_id, inbox_rev)
                if asyncio.iscoroutine(res):
                    await res
            else:
                raise RuntimeError("Unknown metadata outbox job")

            # Complete job
            async with get_async_connection() as conn:
                async with conn.transaction():
                    async with conn.cursor() as cur:
                        await complete_outbox_job(cur, schema, job_id, worker_id)

        except Exception as e:
            logger.error(f"Error processing outbox job {job_id} ({kind}): {e}")
            async with get_async_connection() as conn:
                async with conn.transaction():
                    async with conn.cursor() as cur:
                        await fail_outbox_job(cur, schema, job_id, str(e), worker_id)

    return len(jobs)


async def run_outbox_worker(stop_event: asyncio.Event) -> None:
    """Supervised background loop processing transactional outbox jobs."""
    settings = get_settings()
    worker_id = f"outbox-worker-{uuid.uuid4().hex[:8]}"
    logger.info(f"Starting outbox worker [{worker_id}]")

    while not stop_event.is_set():
        try:
            processed = await process_outbox_batch(
                worker_id=worker_id,
                batch_size=settings.outbox_worker_batch_size,
            )
            if processed == 0:
                # Idle backoff
                await asyncio.sleep(settings.outbox_worker_poll_interval_seconds)
            else:
                # Continue draining without delay
                await asyncio.sleep(0.05)
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"Unexpected error in outbox worker loop: {e}")
            await asyncio.sleep(settings.outbox_worker_poll_interval_seconds)

    logger.info(f"Outbox worker [{worker_id}] stopped cleanly")
