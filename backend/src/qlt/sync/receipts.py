import hashlib
import json
import uuid
from fastapi import HTTPException


def compute_request_hash(data: dict) -> str:
    """Computes a deterministic SHA-256 digest of a request payload."""
    canonical_json = json.dumps(data, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(canonical_json.encode("utf-8")).hexdigest()


def check_receipt(
    cur,
    schema: str,
    user_id: uuid.UUID,
    operation_id: uuid.UUID,
    request_hash: str,
) -> dict | None:
    """
    Checks if an operation has already been executed.
    If executed with matching hash, returns the recorded outcome.
    If executed with a differing hash, raises a 409 Conflict.
    If not yet executed, returns None.
    """
    cur.execute(
        f"""
        SELECT operation_id, request_hash, outcome_code, result_entity_id, created_at
        FROM {schema}.operation_receipts
        WHERE user_id = %s AND operation_id = %s;
        """,
        (str(user_id), str(operation_id)),
    )
    receipt = cur.fetchone()
    if not receipt:
        return None

    if receipt["request_hash"] != request_hash:
        raise HTTPException(
            status_code=409,
            detail="Mã thao tác (operation_id) đã được sử dụng với nội dung khác",
        )

    return {
        "operation_id": str(receipt["operation_id"]),
        "outcome_code": receipt["outcome_code"],
        "result_entity_id": str(receipt["result_entity_id"]) if receipt["result_entity_id"] else None,
        "created_at": receipt["created_at"].isoformat(),
        "replayed": True,
    }


def record_receipt(
    cur,
    schema: str,
    user_id: uuid.UUID,
    operation_id: uuid.UUID,
    request_hash: str,
    outcome_code: str,
    result_entity_id: uuid.UUID | None = None,
) -> None:
    """Records an idempotency receipt for a completed operation."""
    cur.execute(
        f"""
        INSERT INTO {schema}.operation_receipts (
            user_id, operation_id, request_hash, outcome_code, result_entity_id
        ) VALUES (%s, %s, %s, %s, %s);
        """,
        (
            str(user_id),
            str(operation_id),
            request_hash,
            outcome_code,
            str(result_entity_id) if result_entity_id else None,
        ),
    )
async def check_receipt_async(
    cur,
    schema: str,
    user_id: uuid.UUID,
    operation_id: uuid.UUID,
    request_hash: str,
) -> dict | None:
    """Async variant of check_receipt for AsyncCursor."""
    await cur.execute(
        f"""
        SELECT operation_id, request_hash, outcome_code, result_entity_id, created_at
        FROM {schema}.operation_receipts
        WHERE user_id = %s AND operation_id = %s;
        """,
        (str(user_id), str(operation_id)),
    )
    receipt = await cur.fetchone()
    if not receipt:
        return None

    if receipt["request_hash"] != request_hash:
        raise HTTPException(
            status_code=409,
            detail="Mã thao tác (operation_id) đã được sử dụng với nội dung khác",
        )

    return {
        "operation_id": str(receipt["operation_id"]),
        "outcome_code": receipt["outcome_code"],
        "result_entity_id": str(receipt["result_entity_id"]) if receipt["result_entity_id"] else None,
        "created_at": receipt["created_at"].isoformat(),
        "replayed": True,
    }


async def record_receipt_async(
    cur,
    schema: str,
    user_id: uuid.UUID,
    operation_id: uuid.UUID,
    request_hash: str,
    outcome_code: str,
    result_entity_id: uuid.UUID | None = None,
) -> None:
    """Async variant of record_receipt for AsyncCursor."""
    await cur.execute(
        f"""
        INSERT INTO {schema}.operation_receipts (
            user_id, operation_id, request_hash, outcome_code, result_entity_id
        ) VALUES (%s, %s, %s, %s, %s);
        """,
        (
            str(user_id),
            str(operation_id),
            request_hash,
            outcome_code,
            str(result_entity_id) if result_entity_id else None,
        ),
    )
