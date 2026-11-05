import asyncio
import logging
import uuid
from typing import Any

from fastapi import HTTPException
from nats.js.errors import NotFoundError

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.client import get_jetstream
from qlt.messaging.integrity import verified_payload

logger = logging.getLogger(__name__)


async def fetch_single_payload(
    js,
    stream_name: str,
    stream_seq: int,
    receipt: dict[str, Any],
    semaphore: asyncio.Semaphore,
) -> dict[str, Any]:
    """Fetches a single payload from JetStream under bounded concurrency semaphore."""
    async with semaphore:
        try:
            msg = await js.get_msg(stream_name=stream_name, seq=stream_seq)
            payload = verified_payload(msg, receipt)

            # Format to DTO compatible with existing Flutter client and snapshot schema
            return {
                "id": str(receipt["id"]),
                "user_id": str(receipt["user_id"]),
                "binding_id": str(receipt["binding_id"]) if receipt.get("binding_id") else None,
                "bank_code": payload.source_type,
                "owner_account_snapshot": payload.account_number_mask,
                "amount_vnd": str(int(payload.amount)),
                "direction": payload.direction,
                "occurred_at": payload.booking_time.isoformat(),
                "time_source": (payload.raw_payload or {}).get("time_source", "collector"),
                "received_at": receipt["first_received_at"].isoformat(),
                "bank_description": payload.raw_description,
                "version": 1,
                "counterparty_account": payload.counterparty_account,
                "counterparty_bank": payload.counterparty_bank,
                "counterparty_name": payload.counterparty_name,
                "suggested_category_id": str(payload.suggested_category_id) if payload.suggested_category_id else None,
                "suggested_tags": payload.suggested_tags,
            }
        except NotFoundError:
            logger.error(
                f"Integrity error: JetStream message missing for pending receipt {receipt['id']} "
                f"at {stream_name}:{stream_seq}"
            )
            raise HTTPException(
                status_code=503,
                detail="Lỗi đồng bộ dữ liệu: Không tìm thấy nội dung giao dịch ngân hàng đang chờ xử lý",
            )
        except Exception as e:
            logger.error(f"Error fetching payload for event {receipt['id']}: {e}")
            raise HTTPException(
                status_code=503,
                detail="Không thể truy xuất nội dung giao dịch ngân hàng",
            )


async def get_user_inbox_events(
    user_id: uuid.UUID,
    max_retries: int = 3,
) -> tuple[int, list[dict[str, Any]]]:
    """Retrieves consistent pending inbox events for a user with cross-store race detection.
    Returns (inbox_revision, events).
    """
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    for attempt in range(max_retries):
        # 1. Capture metadata and inbox_revision
        async with get_async_connection() as conn:
            async with conn.transaction():
                async with conn.cursor() as cur:
                    await cur.execute(
                        f"""
                        SELECT inbox_revision FROM {schema}.user_revisions
                        WHERE user_id = %s;
                        """,
                        (u_id,),
                    )
                    rev_row = await cur.fetchone()
                    initial_inbox_rev = rev_row["inbox_revision"] if rev_row else 0

                    await cur.execute(
                        f"""
                        SELECT id, user_id, binding_id, fingerprint, stream_name, stream_seq,
                               state, payload_hash, first_received_at
                        FROM {schema}.bank_event_receipts
                        WHERE user_id = %s AND state = 'pending'
                        ORDER BY first_received_at DESC;
                        """,
                        (u_id,),
                    )
                    receipts = await cur.fetchall()

        # 2. Bounded parallel payload reads from JetStream (max 10 concurrent reads)
        js = await get_jetstream() if receipts else None
        if any(not r.get("stream_name") or r.get("stream_seq") is None for r in receipts):
            raise HTTPException(status_code=503, detail="Thiếu vị trí lưu trữ giao dịch ngân hàng")
        semaphore = asyncio.Semaphore(10)
        tasks = [
            fetch_single_payload(
                js=js,
                stream_name=r["stream_name"],
                stream_seq=r["stream_seq"],
                receipt=r,
                semaphore=semaphore,
            )
            for r in receipts
            if r.get("stream_name") and r.get("stream_seq") is not None
        ]

        try:
            events = await asyncio.gather(*tasks)
        except HTTPException:
            if attempt < max_retries - 1:
                await asyncio.sleep(0.1)
                continue
            raise

        # 3. Re-verify inbox_revision to guard against cross-store races during fetch
        async with get_async_connection() as conn:
            async with conn.transaction():
                async with conn.cursor() as cur:
                    await cur.execute(
                        f"""
                        SELECT inbox_revision FROM {schema}.user_revisions
                        WHERE user_id = %s;
                        """,
                        (u_id,),
                    )
                    latest_rev_row = await cur.fetchone()
                    latest_inbox_rev = latest_rev_row["inbox_revision"] if latest_rev_row else 0

        if latest_inbox_rev == initial_inbox_rev:
            return latest_inbox_rev, events

        logger.debug(
            f"Inbox revision drift during snapshot assembly (attempt {attempt + 1}): "
            f"{initial_inbox_rev} -> {latest_inbox_rev}. Retrying..."
        )
        await asyncio.sleep(0.05)

    raise HTTPException(status_code=503, detail="Dữ liệu đang thay đổi, hãy đồng bộ lại")


def get_user_inbox_events_sync(user_id: uuid.UUID) -> tuple[int, list[dict[str, Any]]]:
    from qlt.runtime import run_backend_coroutine
    return run_backend_coroutine(get_user_inbox_events(user_id))
