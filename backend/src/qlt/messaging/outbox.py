import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from qlt.messaging.schemas import OutboxJobKind, OutboxJobStatus


async def enqueue_outbox_job(
    cur,
    schema: str,
    kind: OutboxJobKind,
    user_id: uuid.UUID,
    event_id: uuid.UUID | None = None,
    stream_name: str | None = None,
    stream_seq: int | None = None,
    inbox_revision: int | None = None,
) -> uuid.UUID:
    """Enqueues a metadata-only outbox job within the current database transaction.
    No financial payloads or secrets are stored in outbox jobs.
    """
    job_id = uuid.uuid4()
    await cur.execute(
        f"""
        INSERT INTO {schema}.metadata_outbox_jobs (
            id, kind, user_id, event_id, stream_name, stream_seq,
            inbox_revision, status, attempts, next_attempt_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 0, NOW())
        RETURNING id;
        """,
        (
            str(job_id),
            kind.value,
            str(user_id),
            str(event_id) if event_id else None,
            stream_name,
            stream_seq,
            inbox_revision,
            OutboxJobStatus.PENDING.value,
        ),
    )
    row = await cur.fetchone()
    return row["id"]


async def lease_outbox_jobs(
    cur,
    schema: str,
    worker_id: str,
    batch_size: int = 50,
    lease_seconds: int = 30,
) -> list[dict[str, Any]]:
    """Claims up to `batch_size` runnable outbox jobs using SKIP LOCKED leasing."""
    now = datetime.now(timezone.utc)
    locked_until = now + timedelta(seconds=lease_seconds)

    await cur.execute(
        f"""
        WITH claimable AS (
            SELECT id
            FROM {schema}.metadata_outbox_jobs
            WHERE (
                status = 'pending' AND next_attempt_at <= %s
            ) OR (
                status = 'processing' AND locked_until <= %s
            )
            ORDER BY next_attempt_at ASC
            LIMIT %s
            FOR UPDATE SKIP LOCKED
        )
        UPDATE {schema}.metadata_outbox_jobs j
        SET status = 'processing',
            locked_by = %s,
            locked_until = %s,
            attempts = j.attempts + 1
        FROM claimable
        WHERE j.id = claimable.id
        RETURNING j.id, j.kind, j.user_id, j.event_id, j.stream_name, j.stream_seq,
                  j.inbox_revision, j.attempts, j.max_attempts;
        """,
        (now, now, batch_size, worker_id, locked_until),
    )
    return await cur.fetchall()


async def complete_outbox_job(
    cur,
    schema: str,
    job_id: uuid.UUID,
    worker_id: str,
) -> None:
    """Marks an outbox job as completed."""
    await cur.execute(
        f"""
        UPDATE {schema}.metadata_outbox_jobs
        SET status = 'completed',
            completed_at = NOW(),
            locked_until = NULL,
            locked_by = NULL
        WHERE id = %s AND locked_by = %s AND locked_until > NOW();
        """,
        (str(job_id), worker_id),
    )


async def fail_outbox_job(
    cur,
    schema: str,
    job_id: uuid.UUID,
    error_msg: str,
    worker_id: str,
    retry_delay_seconds: int = 5,
) -> None:
    """Records an outbox job failure with exponential backoff or terminal failure."""
    retry_at = datetime.now(timezone.utc) + timedelta(seconds=retry_delay_seconds)
    await cur.execute(
        f"""
        UPDATE {schema}.metadata_outbox_jobs
        SET status = CASE WHEN kind != 'payload_cleanup' AND attempts >= max_attempts
                         THEN 'failed' ELSE 'pending' END,
            next_attempt_at = %s,
            last_error = %s,
            locked_until = NULL,
            locked_by = NULL
        WHERE id = %s AND locked_by = %s AND locked_until > NOW();
        """,
        (retry_at, error_msg[:500], str(job_id), worker_id),
    )
