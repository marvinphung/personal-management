import uuid

from qlt.db import get_async_connection
from qlt.messaging.outbox import complete_outbox_job, enqueue_outbox_job, fail_outbox_job
from qlt.messaging.schemas import OutboxJobKind


async def test_cleanup_retries_beyond_normal_attempt_limit():
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                job = await enqueue_outbox_job(cur, "qlt", OutboxJobKind.PAYLOAD_CLEANUP, uuid.uuid4(), uuid.uuid4(), "test", 1)
                await cur.execute("UPDATE qlt.metadata_outbox_jobs SET status='processing',attempts=11,locked_by='worker',locked_until=NOW()+INTERVAL '30 seconds' WHERE id=%s", (job,))
                await fail_outbox_job(cur, "qlt", job, "Broker unavailable", "worker")
                await cur.execute("SELECT status FROM qlt.metadata_outbox_jobs WHERE id=%s", (job,))
                assert (await cur.fetchone())["status"] == "pending"
                await cur.execute("DELETE FROM qlt.metadata_outbox_jobs WHERE id=%s", (job,))


async def test_stale_worker_cannot_complete_released_lease():
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                job = await enqueue_outbox_job(cur, "qlt", OutboxJobKind.PAYLOAD_CLEANUP, uuid.uuid4(), uuid.uuid4(), "test", 1)
                await cur.execute("UPDATE qlt.metadata_outbox_jobs SET status='processing',locked_by='new-worker',locked_until=NOW()+INTERVAL '30 seconds' WHERE id=%s", (job,))
                await complete_outbox_job(cur, "qlt", job, "old-worker")
                await cur.execute("SELECT status FROM qlt.metadata_outbox_jobs WHERE id=%s", (job,))
                assert (await cur.fetchone())["status"] == "processing"
                await complete_outbox_job(cur, "qlt", job, "new-worker")
                await cur.execute("SELECT status FROM qlt.metadata_outbox_jobs WHERE id=%s", (job,))
                assert (await cur.fetchone())["status"] == "completed"
                await cur.execute("DELETE FROM qlt.metadata_outbox_jobs WHERE id=%s", (job,))
