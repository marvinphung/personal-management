from datetime import datetime
import uuid
from fastapi import HTTPException
from pydantic import BaseModel
from qlt.catalog.seeds import make_key
from qlt.config import get_settings
from qlt.db import get_connection
from qlt.messaging.resolution import resolve_bank_event
from qlt.sync.receipts import check_receipt, compute_request_hash, record_receipt


def _run_async(coro):
    from qlt.runtime import run_backend_coroutine
    return run_backend_coroutine(coro)



class TypedOperation(BaseModel):
    operation_id: uuid.UUID
    type: str  # 'create_category', 'create_tag', 'create_transaction', 'update_transaction', 'delete_transaction', 'accept_pending', 'discard_pending'
    payload: dict


def execute_operations_batch(user_id: uuid.UUID, operations: list[TypedOperation]) -> list[dict]:
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)
    results = []

    for op in operations:
        req_hash = compute_request_hash({"type": op.type, "payload": op.payload})

        try:
            if op.type in ("accept_pending", "discard_pending"):
                # Resolution owns its transaction and operation receipt. Never
                # hold a sync revision lock while waiting for that transaction.
                accepting = op.type == "accept_pending"
                res = _run_async(resolve_bank_event(
                    user_id=user_id,
                    operation_id=op.operation_id,
                    action="accept" if accepting else "discard",
                    pending_id=uuid.UUID(str(op.payload["pending_id"])),
                    category_id=uuid.UUID(str(op.payload["category_id"])) if accepting else None,
                    tag_ids=[uuid.UUID(str(t)) for t in op.payload.get("tag_ids", [])] if accepting else [],
                    user_note=op.payload.get("user_note", "") if accepting else "",
                    purpose=op.payload.get("purpose", "normal") if accepting else "normal",
                    transaction_id=uuid.UUID(str(op.payload["transaction_id"]))
                        if accepting and op.payload.get("transaction_id") else None,
                ))
                results.append({"operation_id": str(op.operation_id), "status": "success",
                    "outcome_code": res["outcome_code"], "entity_id": res["transaction_id"],
                    "replayed": res["replayed"]})
                continue
            with get_connection() as conn:
                with conn.cursor() as cur:
                    # 1. Check idempotency receipt
                    existing = check_receipt(cur, schema, user_id, op.operation_id, req_hash)
                    if existing:
                        results.append({
                            "operation_id": str(op.operation_id),
                            "status": "success",
                            "outcome_code": existing["outcome_code"],
                            "entity_id": existing["result_entity_id"],
                            "replayed": True,
                        })
                        continue

                    # 2. Lock user revision for consistent ordering
                    cur.execute(
                        f"""
                        INSERT INTO {schema}.user_revisions (user_id, revision)
                        VALUES (%s, 1)
                        ON CONFLICT (user_id) DO UPDATE SET revision = {schema}.user_revisions.revision
                        RETURNING revision;
                        """,
                        (u_id,),
                    )

                    outcome_code = "success"
                    result_entity_id = None
                    extra_data = {}

                    # 3. Handle typed operations
                    if op.type == "create_category":
                        cat_id = op.payload.get("id") or str(uuid.uuid4())
                        name = str(op.payload.get("name", "")).strip()
                        direction = op.payload.get("direction", "expense")
                        icon = op.payload.get("icon", "category")
                        name_key = make_key(name)

                        # Check existing duplicate -> canonical resolution
                        cur.execute(
                            f"SELECT id FROM {schema}.categories WHERE user_id = %s AND direction = %s AND name_key = %s;",
                            (u_id, direction, name_key),
                        )
                        existing_cat = cur.fetchone()
                        if existing_cat:
                            result_entity_id = uuid.UUID(str(existing_cat["id"]))
                            outcome_code = "canonical_resolved"
                            extra_data["canonical_id"] = str(result_entity_id)
                        else:
                            cur.execute(
                                f"""
                                INSERT INTO {schema}.categories (id, user_id, direction, name, name_key, icon, seed_rank)
                                VALUES (%s, %s, %s, %s, %s, %s, 999)
                                RETURNING id;
                                """,
                                (cat_id, u_id, direction, name, name_key, icon),
                            )
                            result_entity_id = uuid.UUID(cat_id)

                    elif op.type == "create_tag":
                        tag_id = op.payload.get("id") or str(uuid.uuid4())
                        category_id = str(op.payload["category_id"])
                        name = str(op.payload.get("name", "")).strip()
                        name_key = make_key(name)

                        cur.execute(
                            f"SELECT id FROM {schema}.tags WHERE user_id = %s AND category_id = %s AND name_key = %s;",
                            (u_id, category_id, name_key),
                        )
                        existing_tag = cur.fetchone()
                        if existing_tag:
                            result_entity_id = uuid.UUID(str(existing_tag["id"]))
                            outcome_code = "canonical_resolved"
                            extra_data["canonical_id"] = str(result_entity_id)
                        else:
                            cur.execute(
                                f"""
                                INSERT INTO {schema}.tags (id, user_id, category_id, name, name_key)
                                VALUES (%s, %s, %s, %s, %s)
                                RETURNING id;
                                """,
                                (tag_id, u_id, category_id, name, name_key),
                            )
                            result_entity_id = uuid.UUID(tag_id)

                    elif op.type == "create_transaction":
                        tx_id = op.payload.get("id") or str(uuid.uuid4())
                        amount = int(op.payload["amount_vnd"])
                        occurred = datetime.fromisoformat(op.payload["occurred_at"].replace("Z", "+00:00"))
                        direction = op.payload["direction"]
                        category_id = str(op.payload["category_id"])
                        tag_ids = op.payload.get("tag_ids", [])
                        user_note = op.payload.get("user_note", "")
                        purpose = op.payload.get("purpose", "normal")

                        cur.execute(
                            f"""
                            INSERT INTO {schema}.transactions (
                                id, user_id, direction, amount_vnd, occurred_at, source,
                                category_id, user_note, purpose, version
                            ) VALUES (%s, %s, %s, %s, %s, 'manual', %s, %s, %s, 1)
                            RETURNING id;
                            """,
                            (tx_id, u_id, direction, amount, occurred, category_id, user_note, purpose),
                        )
                        for t_id in tag_ids:
                            cur.execute(
                                f"INSERT INTO {schema}.transaction_tags (user_id, transaction_id, tag_id) VALUES (%s, %s, %s);",
                                (u_id, tx_id, str(t_id)),
                            )
                        result_entity_id = uuid.UUID(tx_id)

                    elif op.type == "update_transaction":
                        tx_id = str(op.payload["transaction_id"])
                        base_version = op.payload.get("base_version")
                        cur.execute(
                            f"SELECT * FROM {schema}.transactions WHERE id = %s AND user_id = %s FOR UPDATE;",
                            (tx_id, u_id),
                        )
                        tx = cur.fetchone()
                        if not tx:
                            results.append({
                                "operation_id": str(op.operation_id),
                                "status": "error",
                                "code": "NOT_FOUND",
                                "message": "Giao dịch không tồn tại",
                            })
                            continue
                        if base_version is not None and tx["version"] != base_version:
                            results.append({
                                "operation_id": str(op.operation_id),
                                "status": "conflict",
                                "code": "VERSION_CONFLICT",
                                "server_version": tx["version"],
                            })
                            continue

                        is_bank = tx["source"] == "bank"
                        cat_id = op.payload.get("category_id") or str(tx["category_id"])
                        note = op.payload.get("user_note") if op.payload.get("user_note") is not None else tx["user_note"]
                        amount = int(op.payload["amount_vnd"]) if (op.payload.get("amount_vnd") and not is_bank) else tx["amount_vnd"]
                        direction = op.payload.get("direction") if (op.payload.get("direction") and not is_bank) else tx["direction"]
                        occurred = (
                            datetime.fromisoformat(op.payload["occurred_at"].replace("Z", "+00:00"))
                            if (op.payload.get("occurred_at") and not is_bank)
                            else tx["occurred_at"]
                        )

                        cur.execute(
                            f"""
                            UPDATE {schema}.transactions
                            SET category_id = %s, user_note = %s, amount_vnd = %s, direction = %s,
                                occurred_at = %s, version = version + 1
                            WHERE id = %s;
                            """,
                            (cat_id, note, amount, direction, occurred, tx_id),
                        )
                        if "tag_ids" in op.payload and op.payload["tag_ids"] is not None:
                            cur.execute(
                                f"DELETE FROM {schema}.transaction_tags WHERE transaction_id = %s AND user_id = %s;",
                                (tx_id, u_id),
                            )
                            for t_id in op.payload["tag_ids"]:
                                cur.execute(
                                    f"INSERT INTO {schema}.transaction_tags (user_id, transaction_id, tag_id) VALUES (%s, %s, %s);",
                                    (u_id, tx_id, str(t_id)),
                                )
                        result_entity_id = uuid.UUID(tx_id)

                    elif op.type == "delete_transaction":
                        tx_id = str(op.payload["transaction_id"])
                        cur.execute(
                            f"DELETE FROM {schema}.transactions WHERE id = %s AND user_id = %s;",
                            (tx_id, u_id),
                        )
                        result_entity_id = uuid.UUID(tx_id)


                    else:
                        results.append({
                            "operation_id": str(op.operation_id),
                            "status": "error",
                            "code": "UNKNOWN_OPERATION_TYPE",
                            "message": f"Loại thao tác không xác định: {op.type}",
                        })
                        continue

                    # Record receipt
                    record_receipt(
                        cur,
                        schema,
                        user_id,
                        op.operation_id,
                        req_hash,
                        outcome_code=outcome_code,
                        result_entity_id=result_entity_id,
                    )

                    # Increment revision
                    cur.execute(
                        f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                        (u_id,),
                    )
                conn.commit()

            res = {
                "operation_id": str(op.operation_id),
                "status": "success",
                "outcome_code": outcome_code,
                "entity_id": str(result_entity_id) if result_entity_id else None,
                "replayed": False,
            }
            res.update(extra_data)
            results.append(res)

        except Exception as e:
            results.append({
                "operation_id": str(op.operation_id),
                "status": "error",
                "code": "EXECUTION_ERROR",
                "message": str(e),
            })

    return results
