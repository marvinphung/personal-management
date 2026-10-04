import hashlib
import json
import uuid
from datetime import datetime, timezone
from typing import Any

from qlt.messaging.schemas import ReceiptState


def compute_payload_hash(data: dict) -> str:
    """Computes a deterministic SHA-256 digest of normalized bank event content."""
    canonical = json.dumps(data, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


async def find_receipt_by_fingerprint(
    cur,
    schema: str,
    fingerprint: str,
) -> dict[str, Any] | None:
    """Finds a receipt by its unique HMAC fingerprint."""
    await cur.execute(
        f"""
        SELECT id, user_id, binding_id, fingerprint, stream_name, stream_seq,
               state, payload_hash, capture_epoch, binding_version, first_received_at, resolved_at, discarded_at, created_at
        FROM {schema}.bank_event_receipts
        WHERE fingerprint = %s;
        """,
        (fingerprint,),
    )
    return await cur.fetchone()


async def find_receipt_by_id(
    cur,
    schema: str,
    event_id: uuid.UUID,
) -> dict[str, Any] | None:
    """Finds a receipt by event UUID."""
    await cur.execute(
        f"""
        SELECT id, user_id, binding_id, fingerprint, stream_name, stream_seq,
               state, payload_hash, capture_epoch, binding_version, first_received_at, resolved_at, discarded_at, created_at
        FROM {schema}.bank_event_receipts
        WHERE id = %s;
        """,
        (str(event_id),),
    )
    return await cur.fetchone()


async def lock_receipt_by_id(
    cur,
    schema: str,
    event_id: uuid.UUID,
) -> dict[str, Any] | None:
    """Locks a receipt row FOR UPDATE to serialize resolution or ingestion retry."""
    await cur.execute(
        f"""
        SELECT id, user_id, binding_id, fingerprint, stream_name, stream_seq,
               state, payload_hash, capture_epoch, binding_version, first_received_at, resolved_at, discarded_at, created_at
        FROM {schema}.bank_event_receipts
        WHERE id = %s
        FOR UPDATE;
        """,
        (str(event_id),),
    )
    return await cur.fetchone()


async def reserve_receipt(
    cur,
    schema: str,
    event_id: uuid.UUID,
    user_id: uuid.UUID,
    binding_id: uuid.UUID | None,
    fingerprint: str,
    payload_hash: str,
    capture_epoch: int | None = None,
    binding_version: int | None = None,
) -> dict[str, Any]:
    """Reserves a bank event receipt in 'publishing' state before JetStream publish."""
    # Ensure ingest_receipts entry exists for FK
    await cur.execute(
        f"""
        INSERT INTO {schema}.ingest_receipts (fingerprint, algorithm_version)
        VALUES (%s, 'v1')
        ON CONFLICT (fingerprint) DO NOTHING;
        """,
        (fingerprint,),
    )

    await cur.execute(
        f"""
        INSERT INTO {schema}.bank_event_receipts (
            id, user_id, binding_id, fingerprint, state, payload_hash, capture_epoch, binding_version
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id, user_id, binding_id, fingerprint, state, payload_hash, created_at;
        """,
        (
            str(event_id),
            str(user_id),
            str(binding_id) if binding_id else None,
            fingerprint,
            ReceiptState.PUBLISHING.value,
            payload_hash,
            capture_epoch,
            binding_version,
        ),
    )
    return await cur.fetchone()


async def commit_receipt_pending(
    cur,
    schema: str,
    event_id: uuid.UUID,
    user_id: uuid.UUID,
    stream_name: str,
    stream_seq: int,
) -> int | None:
    """Transitions a receipt from 'publishing' to 'pending' and bumps user inbox_revision.
    Returns the new inbox_revision.
    """
    await cur.execute(
        f"""
        UPDATE {schema}.bank_event_receipts
        SET state = %s,
            stream_name = %s,
            stream_seq = %s
        WHERE id = %s AND user_id = %s AND state = 'publishing'
        RETURNING id;
        """,
        (ReceiptState.PENDING.value, stream_name, stream_seq, str(event_id), str(user_id)),
    )
    if not await cur.fetchone():
        return None

    # Bump user inbox_revision atomically
    await cur.execute(
        f"""
        INSERT INTO {schema}.user_revisions (user_id, revision, inbox_revision)
        VALUES (%s, 1, 1)
        ON CONFLICT (user_id) DO UPDATE
        SET inbox_revision = {schema}.user_revisions.inbox_revision + 1
        RETURNING inbox_revision;
        """,
        (str(user_id),),
    )
    row = await cur.fetchone()
    return row["inbox_revision"] if row else 1


async def resolve_receipt(
    cur,
    schema: str,
    event_id: uuid.UUID,
    user_id: uuid.UUID,
    terminal_state: ReceiptState,
) -> int:
    """Transitions a receipt from 'pending' to 'accepted' or 'discarded' and bumps inbox_revision."""
    now = datetime.now(timezone.utc)
    resolved_at = now if terminal_state == ReceiptState.ACCEPTED else None
    discarded_at = now if terminal_state == ReceiptState.DISCARDED else None

    await cur.execute(
        f"""
        UPDATE {schema}.bank_event_receipts
        SET state = %s,
            resolved_at = COALESCE(%s, resolved_at),
            discarded_at = COALESCE(%s, discarded_at)
        WHERE id = %s AND user_id = %s;
        """,
        (terminal_state.value, resolved_at, discarded_at, str(event_id), str(user_id)),
    )

    # Bump user inbox_revision
    await cur.execute(
        f"""
        INSERT INTO {schema}.user_revisions (user_id, revision, inbox_revision)
        VALUES (%s, 1, 1)
        ON CONFLICT (user_id) DO UPDATE
        SET inbox_revision = {schema}.user_revisions.inbox_revision + 1
        RETURNING inbox_revision;
        """,
        (str(user_id),),
    )
    row = await cur.fetchone()
    return row["inbox_revision"] if row else 1


async def count_pending_receipts(
    cur,
    schema: str,
    user_id: uuid.UUID,
) -> int:
    """Counts pending events for a user."""
    await cur.execute(
        f"""
        SELECT COUNT(*) as count
        FROM {schema}.bank_event_receipts
        WHERE user_id = %s AND state = 'pending';
        """,
        (str(user_id),),
    )
    row = await cur.fetchone()
    return row["count"] if row else 0


async def list_pending_receipts(
    cur,
    schema: str,
    user_id: uuid.UUID,
    limit: int = 200,
) -> list[dict[str, Any]]:
    """Lists pending event metadata rows for a user in chronological order."""
    await cur.execute(
        f"""
        SELECT id, user_id, binding_id, fingerprint, stream_name, stream_seq,
               state, payload_hash, first_received_at, created_at
        FROM {schema}.bank_event_receipts
        WHERE user_id = %s AND state = 'pending'
        ORDER BY first_received_at ASC
        LIMIT %s;
        """,
        (str(user_id), limit),
    )
    return await cur.fetchall()


# Sync helper functions for synchronous paths (if needed)
def sync_find_receipt_by_id(cur, schema: str, event_id: uuid.UUID) -> dict[str, Any] | None:
    cur.execute(
        f"""
        SELECT id, user_id, binding_id, fingerprint, stream_name, stream_seq,
               state, payload_hash, capture_epoch, binding_version, first_received_at, resolved_at, discarded_at, created_at
        FROM {schema}.bank_event_receipts
        WHERE id = %s;
        """,
        (str(event_id),),
    )
    return cur.fetchone()


def sync_count_pending_receipts(cur, schema: str, user_id: uuid.UUID) -> int:
    cur.execute(
        f"""
        SELECT COUNT(*) as count
        FROM {schema}.bank_event_receipts
        WHERE user_id = %s AND state = 'pending';
        """,
        (str(user_id),),
    )
    row = cur.fetchone()
    return row["count"] if row else 0
