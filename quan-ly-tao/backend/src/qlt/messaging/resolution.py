import logging
import uuid
from typing import Any

from fastapi import HTTPException
from nats.js.errors import NotFoundError

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.cleanup import delete_event_payload
from qlt.messaging.client import get_jetstream
from qlt.messaging.integrity import verified_payload
from qlt.messaging.outbox import enqueue_outbox_job
from qlt.messaging.receipts import (
    lock_receipt_by_id,
    resolve_receipt,
)
from qlt.messaging.schemas import (
    OutboxJobKind,
    ReceiptState,
)
from qlt.sync.receipts import (
    check_receipt_async,
    compute_request_hash,
    record_receipt_async,
)

logger = logging.getLogger(__name__)


async def resolve_bank_event(
    user_id: uuid.UUID,
    operation_id: uuid.UUID,
    action: str,  # "accept" or "discard"
    pending_id: uuid.UUID,
    category_id: uuid.UUID | None = None,
    tag_ids: list[uuid.UUID] | None = None,
    user_note: str = "",
    purpose: str = "normal",
    transaction_id: uuid.UUID | None = None,
) -> dict[str, Any]:
    """Centralized, idempotent resolution service for bank inbox events.
    Supports both direct HTTP commands and offline sync batched operations.
    Enforces documented lock order: user_revisions -> bank_event_receipts.
    """
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)
    tag_ids = tag_ids or []

    # Deterministic request hash for operation receipt
    request_data = {
        "pending_id": str(pending_id),
        "operation_id": str(operation_id),
        "action": action,
    }
    if action == "accept":
        request_data.update({
            "category_id": str(category_id),
            "tag_ids": sorted([str(t) for t in tag_ids]),
            "user_note": user_note,
            "purpose": purpose,
            "transaction_id": str(transaction_id) if transaction_id else None,
        })
    req_hash = compute_request_hash(request_data)

    stream_name: str | None = None
    stream_seq: int | None = None
    tx_id: uuid.UUID | None = transaction_id or uuid.uuid4()

    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(f"SELECT status FROM {schema}.users WHERE id=%s FOR SHARE", (u_id,))
                owner = await cur.fetchone()
                if not owner or owner["status"] != "active":
                    raise HTTPException(status_code=403, detail="Tài khoản không hoạt động")
                # 2. Lock user revision row for consistent global order
                await cur.execute(
                    f"""
                    INSERT INTO {schema}.user_revisions (user_id, revision, inbox_revision)
                    VALUES (%s, 1, 1)
                    ON CONFLICT (user_id) DO UPDATE SET revision = {schema}.user_revisions.revision
                    RETURNING revision, inbox_revision;
                    """,
                    (u_id,),
                )

                # Recheck after acquiring the serialization lock, including when
                # two devices retry the same operation_id concurrently.
                existing_op = await check_receipt_async(cur, schema, user_id, operation_id, req_hash)
                if existing_op:
                    return {
                        "message": "Thao tác đã được thực hiện trước đó",
                        "transaction_id": existing_op["result_entity_id"],
                        "outcome_code": existing_op["outcome_code"],
                        "replayed": True,
                    }

                # 3. Lock receipt row
                receipt = await lock_receipt_by_id(cur, schema, pending_id)
                if not receipt or str(receipt["user_id"]) != u_id:
                    # Guessed or missing event ID: do not leak state
                    raise HTTPException(
                        status_code=404,
                        detail="Sự kiện ngân hàng không tồn tại hoặc đã được xử lý",
                    )

                state = receipt["state"]
                stream_name = receipt["stream_name"]
                stream_seq = receipt["stream_seq"]

                # 4. If already terminal on another device, return stable outcome (first committed resolution wins)
                if state in (ReceiptState.ACCEPTED.value, ReceiptState.DISCARDED.value, ReceiptState.PURGED.value):
                    await record_receipt_async(
                        cur,
                        schema,
                        user_id,
                        operation_id,
                        req_hash,
                        outcome_code="already_resolved",
                        result_entity_id=None,
                    )
                    return {
                        "message": "Sự kiện ngân hàng đã được giải quyết bởi thiết bị khác",
                        "transaction_id": None,
                        "outcome_code": "already_resolved",
                        "replayed": False,
                    }

                if state != ReceiptState.PENDING.value:
                    raise HTTPException(status_code=409, detail="Sự kiện đang được đồng bộ, hãy thử lại")

                # 5. Process acceptance or discard
                if action == "accept":
                    if not category_id:
                        raise HTTPException(status_code=400, detail="Thiếu danh mục khi chấp nhận giao dịch")

                    # Retrieve immutable payload from JetStream
                    js = await get_jetstream()
                    if not stream_name or stream_seq is None:
                        raise HTTPException(status_code=500, detail="Không tìm thấy thông tin vị trí lưu trữ sự kiện")

                    try:
                        raw_msg = await js.get_msg(stream_name=stream_name, seq=stream_seq)
                        payload = verified_payload(raw_msg, receipt)
                    except Exception as e:
                        logger.error(f"Failed to retrieve immutable payload from JetStream seq {stream_seq}: {e}")
                        raise HTTPException(status_code=500, detail="Không thể truy xuất nội dung gốc của giao dịch")

                    # Validate category ownership and direction
                    await cur.execute(
                        f"SELECT id, direction FROM {schema}.categories WHERE id = %s AND user_id = %s;",
                        (str(category_id), u_id),
                    )
                    cat = await cur.fetchone()
                    if not cat:
                        raise HTTPException(status_code=400, detail="Danh mục không hợp lệ hoặc không thuộc về người dùng")
                    if cat["direction"] != payload.direction:
                        raise HTTPException(
                            status_code=422,
                            detail=f"Chiều của danh mục ({cat['direction']}) không khớp với biến động ({payload.direction})",
                        )

                    # Validate tag ownership
                    if tag_ids:
                        await cur.execute(
                            f"""
                            SELECT id FROM {schema}.tags
                            WHERE user_id = %s AND category_id = %s AND id = ANY(%s::uuid[]);
                            """,
                            (u_id, str(category_id), [str(t) for t in tag_ids]),
                        )
                        valid_tags = {str(r["id"]) for r in await cur.fetchall()}
                        if len(valid_tags) != len(tag_ids):
                            raise HTTPException(status_code=400, detail="Tag không thuộc danh mục này hoặc không hợp lệ")

                    # Insert transaction into ledger taking financial fields strictly from JetStream payload
                    amount_vnd = int(payload.amount)
                    await cur.execute(
                        f"""
                        INSERT INTO {schema}.transactions (
                            id, user_id, direction, amount_vnd, occurred_at, source,
                            bank_code_snapshot, owner_account_snapshot, bank_description,
                            category_id, user_note, purpose, version, source_event_key
                        ) VALUES (%s, %s, %s, %s, %s, 'bank', %s, %s, %s, %s, %s, %s, 1, %s)
                        RETURNING id;
                        """,
                        (
                            str(tx_id),
                            u_id,
                            payload.direction,
                            amount_vnd,
                            payload.booking_time,
                            payload.source_type,
                            payload.account_number_mask,
                            payload.raw_description,
                            str(category_id),
                            user_note,
                            purpose,
                            receipt["fingerprint"],
                        ),
                    )

                    # Insert transaction tags
                    for t_id in tag_ids:
                        await cur.execute(
                            f"INSERT INTO {schema}.transaction_tags (user_id, transaction_id, tag_id) VALUES (%s, %s, %s);",
                            (u_id, str(tx_id), str(t_id)),
                        )

                    # Update receipt state to accepted and bump inbox_revision
                    inbox_rev = await resolve_receipt(cur, schema, pending_id, user_id, ReceiptState.ACCEPTED)
                    outcome_code = "accepted"

                elif action == "discard":
                    # Update receipt state to discarded and bump inbox_revision
                    inbox_rev = await resolve_receipt(cur, schema, pending_id, user_id, ReceiptState.DISCARDED)
                    outcome_code = "discarded"
                    tx_id = None
                else:
                    raise HTTPException(status_code=400, detail=f"Hành động không xác định: {action}")

                # Record idempotency operation receipt
                await record_receipt_async(
                    cur,
                    schema,
                    user_id,
                    operation_id,
                    req_hash,
                    outcome_code=outcome_code,
                    result_entity_id=tx_id,
                )

                # Bump base revision
                await cur.execute(
                    f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                    (u_id,),
                )

                # Enqueue metadata outbox jobs: payload cleanup, realtime invalidation, push refresh
                if stream_name and stream_seq is not None:
                    await enqueue_outbox_job(
                        cur=cur,
                        schema=schema,
                        kind=OutboxJobKind.PAYLOAD_CLEANUP,
                        user_id=user_id,
                        event_id=pending_id,
                        stream_name=stream_name,
                        stream_seq=stream_seq,
                        inbox_revision=inbox_rev,
                    )

                await enqueue_outbox_job(
                    cur=cur,
                    schema=schema,
                    kind=OutboxJobKind.REALTIME_INVALIDATION,
                    user_id=user_id,
                    event_id=pending_id,
                    stream_name=stream_name,
                    stream_seq=stream_seq,
                    inbox_revision=inbox_rev,
                )
                await enqueue_outbox_job(
                    cur=cur,
                    schema=schema,
                    kind=OutboxJobKind.PUSH_REFRESH,
                    user_id=user_id,
                    event_id=pending_id,
                    stream_name=stream_name,
                    stream_seq=stream_seq,
                    inbox_revision=inbox_rev,
                )

    # 6. Eager cleanup attempt after commit (non-blocking)
    if stream_name and stream_seq is not None:
        try:
            js = await get_jetstream()
            await delete_event_payload(js, stream_name, user_id, pending_id)
            logger.info(f"Eagerly deleted broker message {stream_name}:{stream_seq} for event {pending_id}")
        except NotFoundError:
            pass
        except Exception as e:
            logger.warning(f"Eager broker cleanup deferred to outbox worker for event {pending_id}: {e}")

    return {
        "message": "Chấp nhận giao dịch thành công" if action == "accept" else "Đã bỏ qua sự kiện ngân hàng",
        "transaction_id": str(tx_id) if tx_id else None,
        "outcome_code": outcome_code,
        "replayed": False,
    }
