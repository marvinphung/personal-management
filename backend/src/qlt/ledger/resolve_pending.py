import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from qlt.auth.dependencies import require_active_user
from qlt.config import get_settings
from qlt.db import get_connection
from qlt.sync.receipts import check_receipt, compute_request_hash, record_receipt

router = APIRouter(prefix="/v1", tags=["Pending Bank Events"])


class AcceptPendingRequest(BaseModel):
    operation_id: uuid.UUID
    category_id: uuid.UUID
    tag_ids: list[uuid.UUID] = []
    user_note: str = ""
    purpose: str = "normal"  # 'normal', 'debt_principal', 'installment_payment'


class DiscardPendingRequest(BaseModel):
    operation_id: uuid.UUID


@router.get("/pending-events")
def list_pending_events(
    user: dict = Depends(require_active_user),
):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT id, bank_code, owner_account_snapshot, amount_vnd, direction,
                       occurred_at, time_source, received_at, bank_description, version
                FROM {schema}.pending_bank_events
                WHERE user_id = %s
                ORDER BY occurred_at DESC, id DESC;
                """,
                (u_id,),
            )
            rows = cur.fetchall()

    return [
        {
            "id": str(r["id"]),
            "bank_code": r["bank_code"],
            "owner_account_snapshot": r["owner_account_snapshot"],
            "amount_vnd": str(r["amount_vnd"]),
            "direction": r["direction"],
            "occurred_at": r["occurred_at"].isoformat(),
            "time_source": r["time_source"],
            "received_at": r["received_at"].isoformat(),
            "bank_description": r["bank_description"],
            "version": r["version"],
        }
        for r in rows
    ]


@router.post("/pending-events/{pending_id}/accept", status_code=status.HTTP_200_OK)
def accept_pending_event(
    pending_id: uuid.UUID,
    req: AcceptPendingRequest,
    user: dict = Depends(require_active_user),
):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    payload_dict = {
        "pending_id": str(pending_id),
        "operation_id": str(req.operation_id),
        "category_id": str(req.category_id),
        "tag_ids": sorted([str(t) for t in req.tag_ids]),
        "user_note": req.user_note,
        "purpose": req.purpose,
    }
    req_hash = compute_request_hash(payload_dict)

    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. Check idempotency receipt
            existing_receipt = check_receipt(cur, schema, user["user_id"], req.operation_id, req_hash)
            if existing_receipt:
                return {
                    "message": "Thao tác đã được thực hiện trước đó",
                    "transaction_id": existing_receipt["result_entity_id"],
                    "replayed": True,
                }

            # 2. Lock user revision row first for consistent ordering
            cur.execute(
                f"""
                INSERT INTO {schema}.user_revisions (user_id, revision)
                VALUES (%s, 1)
                ON CONFLICT (user_id) DO UPDATE SET revision = {schema}.user_revisions.revision
                RETURNING revision;
                """,
                (u_id,),
            )

            # 3. Lock pending event
            cur.execute(
                f"""
                SELECT * FROM {schema}.pending_bank_events
                WHERE id = %s AND user_id = %s
                FOR UPDATE;
                """,
                (str(pending_id), u_id),
            )
            pending = cur.fetchone()
            if not pending:
                raise HTTPException(
                    status_code=404,
                    detail="Sự kiện ngân hàng không tồn tại hoặc đã được xử lý",
                )

            # 4. Validate category belongs to user and matches direction
            cur.execute(
                f"SELECT id, direction FROM {schema}.categories WHERE id = %s AND user_id = %s;",
                (str(req.category_id), u_id),
            )
            cat = cur.fetchone()
            if not cat:
                raise HTTPException(status_code=400, detail="Danh mục không hợp lệ hoặc không thuộc về người dùng")
            if cat["direction"] != pending["direction"]:
                raise HTTPException(
                    status_code=422,
                    detail=f"Chiều của danh mục ({cat['direction']}) không khớp với biến động ({pending['direction']})",
                )

            # 5. Validate tag ownership
            if req.tag_ids:
                cur.execute(
                    f"""
                    SELECT id FROM {schema}.tags
                    WHERE user_id = %s AND category_id = %s AND id = ANY(%s::uuid[]);
                    """,
                    (u_id, str(req.category_id), [str(t) for t in req.tag_ids]),
                )
                valid_tags = {str(r["id"]) for r in cur.fetchall()}
                if len(valid_tags) != len(req.tag_ids):
                    raise HTTPException(status_code=400, detail="Tag không thuộc danh mục này hoặc không hợp lệ")

            # 6. Insert transaction taking financial fields strictly from database
            tx_id = uuid.uuid4()
            cur.execute(
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
                    pending["direction"],
                    pending["amount_vnd"],
                    pending["occurred_at"],
                    pending["bank_code"],
                    pending["owner_account_snapshot"],
                    pending["bank_description"],
                    str(req.category_id),
                    req.user_note,
                    req.purpose,
                    pending["fingerprint"],
                ),
            )

            # 7. Insert tags
            for t_id in req.tag_ids:
                cur.execute(
                    f"INSERT INTO {schema}.transaction_tags (user_id, transaction_id, tag_id) VALUES (%s, %s, %s);",
                    (u_id, str(tx_id), str(t_id)),
                )

            # 8. Delete from pending_bank_events
            cur.execute(
                f"DELETE FROM {schema}.pending_bank_events WHERE id = %s AND user_id = %s;",
                (str(pending_id), u_id),
            )

            # 9. Record operation receipt
            record_receipt(
                cur,
                schema,
                user["user_id"],
                req.operation_id,
                req_hash,
                outcome_code="accepted",
                result_entity_id=tx_id,
            )

            # 10. Increment user revision
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                (u_id,),
            )
        conn.commit()

    return {
        "message": "Chấp nhận giao dịch thành công",
        "transaction_id": str(tx_id),
        "replayed": False,
    }


@router.post("/pending-events/{pending_id}/discard", status_code=status.HTTP_200_OK)
def discard_pending_event(
    pending_id: uuid.UUID,
    req: DiscardPendingRequest,
    user: dict = Depends(require_active_user),
):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    payload_dict = {
        "pending_id": str(pending_id),
        "operation_id": str(req.operation_id),
        "action": "discard",
    }
    req_hash = compute_request_hash(payload_dict)

    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. Check idempotency receipt
            existing_receipt = check_receipt(cur, schema, user["user_id"], req.operation_id, req_hash)
            if existing_receipt:
                return {
                    "message": "Thao tác bỏ qua đã được thực hiện trước đó",
                    "replayed": True,
                }

            # 2. Lock user revision row first
            cur.execute(
                f"""
                INSERT INTO {schema}.user_revisions (user_id, revision)
                VALUES (%s, 1)
                ON CONFLICT (user_id) DO UPDATE SET revision = {schema}.user_revisions.revision
                RETURNING revision;
                """,
                (u_id,),
            )

            # 3. Lock pending event
            cur.execute(
                f"""
                SELECT id FROM {schema}.pending_bank_events
                WHERE id = %s AND user_id = %s
                FOR UPDATE;
                """,
                (str(pending_id), u_id),
            )
            pending = cur.fetchone()
            if not pending:
                raise HTTPException(
                    status_code=404,
                    detail="Sự kiện ngân hàng không tồn tại hoặc đã được xử lý",
                )

            # 4. Delete pending event
            cur.execute(
                f"DELETE FROM {schema}.pending_bank_events WHERE id = %s AND user_id = %s;",
                (str(pending_id), u_id),
            )

            # 5. Record operation receipt
            record_receipt(
                cur,
                schema,
                user["user_id"],
                req.operation_id,
                req_hash,
                outcome_code="discarded",
                result_entity_id=None,
            )

            # 6. Increment revision
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                (u_id,),
            )
        conn.commit()

    return {
        "message": "Đã bỏ qua sự kiện ngân hàng",
        "replayed": False,
    }
