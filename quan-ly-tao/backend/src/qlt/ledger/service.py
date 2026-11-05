from datetime import datetime, timezone
import uuid
from fastapi import HTTPException
from pydantic import BaseModel
from qlt.config import get_settings
from qlt.db import get_connection


class TransactionCreateRequest(BaseModel):
    direction: str  # 'income' or 'expense'
    amount_vnd: str  # positive decimal string
    occurred_at: str
    category_id: str
    tag_ids: list[str] = []
    user_note: str = ""
    purpose: str = "normal"


class TransactionUpdateRequest(BaseModel):
    category_id: str | None = None
    tag_ids: list[str] | None = None
    user_note: str | None = None
    # For manual transactions only:
    amount_vnd: str | None = None
    occurred_at: str | None = None
    direction: str | None = None


def create_manual_transaction(req: TransactionCreateRequest, user_id: uuid.UUID) -> dict:
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    amount = int(req.amount_vnd)
    if amount <= 0 or amount > 9_000_000_000_000_000:
        raise HTTPException(status_code=422, detail="Số tiền không hợp lệ")

    occurred_dt = datetime.fromisoformat(req.occurred_at.replace("Z", "+00:00"))
    tx_id = uuid.uuid4()

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Validate category belongs to user
            cur.execute(
                f"SELECT id FROM {schema}.categories WHERE id = %s AND user_id = %s;",
                (req.category_id, u_id),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=400, detail="Danh mục không hợp lệ hoặc không thuộc về người dùng")

            # Validate tags belong to user and category
            if req.tag_ids:
                cur.execute(
                    f"""
                    SELECT id FROM {schema}.tags
                    WHERE user_id = %s AND category_id = %s AND id = ANY(%s::uuid[]);
                    """,
                    (u_id, req.category_id, req.tag_ids),
                )
                valid_tags = {str(r["id"]) for r in cur.fetchall()}
                if len(valid_tags) != len(req.tag_ids):
                    raise HTTPException(status_code=400, detail="Tag không hợp lệ hoặc không thuộc danh mục này")

            # Insert transaction
            cur.execute(
                f"""
                INSERT INTO {schema}.transactions (
                    id, user_id, direction, amount_vnd, occurred_at, source,
                    category_id, user_note, purpose, version
                ) VALUES (%s, %s, %s, %s, %s, 'manual', %s, %s, %s, 1)
                RETURNING id, occurred_at, version;
                """,
                (str(tx_id), u_id, req.direction, amount, occurred_dt, req.category_id, req.user_note, req.purpose),
            )
            row = cur.fetchone()

            # Insert transaction_tags
            for tag_id in req.tag_ids:
                cur.execute(
                    f"INSERT INTO {schema}.transaction_tags (user_id, transaction_id, tag_id) VALUES (%s, %s, %s);",
                    (u_id, str(tx_id), tag_id),
                )

            # Increment user revision
            cur.execute(
                f"""
                INSERT INTO {schema}.user_revisions (user_id, revision) VALUES (%s, 1)
                ON CONFLICT (user_id) DO UPDATE SET revision = {schema}.user_revisions.revision + 1;
                """,
                (u_id,),
            )
        conn.commit()

    return {
        "id": str(tx_id),
        "user_id": u_id,
        "direction": req.direction,
        "amount_vnd": str(amount),
        "occurred_at": row["occurred_at"].isoformat(),
        "source": "manual",
        "category_id": req.category_id,
        "tag_ids": req.tag_ids,
        "user_note": req.user_note,
        "purpose": req.purpose,
        "version": row["version"],
    }


def update_transaction(tx_id: uuid.UUID, req: TransactionUpdateRequest, user_id: uuid.UUID) -> dict:
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT * FROM {schema}.transactions WHERE id = %s AND user_id = %s;",
                (str(tx_id), u_id),
            )
            tx = cur.fetchone()
            if not tx:
                raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")

            is_bank = tx["source"] == "bank"

            # If bank transaction, financial fields are strictly read-only
            if is_bank and (req.amount_vnd is not None or req.occurred_at is not None or req.direction is not None):
                raise HTTPException(
                    status_code=400,
                    detail="Không thể sửa đổi số tiền, thời gian hoặc chiều tiền của giao dịch từ ngân hàng",
                )

            new_category_id = req.category_id or str(tx["category_id"])
            # Validate category
            cur.execute(
                f"SELECT id FROM {schema}.categories WHERE id = %s AND user_id = %s;",
                (new_category_id, u_id),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=400, detail="Danh mục không hợp lệ")

            new_note = req.user_note if req.user_note is not None else tx["user_note"]
            new_amount = int(req.amount_vnd) if (req.amount_vnd and not is_bank) else tx["amount_vnd"]
            new_occurred = (
                datetime.fromisoformat(req.occurred_at.replace("Z", "+00:00"))
                if (req.occurred_at and not is_bank)
                else tx["occurred_at"]
            )
            new_direction = req.direction if (req.direction and not is_bank) else tx["direction"]

            cur.execute(
                f"""
                UPDATE {schema}.transactions
                SET category_id = %s, user_note = %s, amount_vnd = %s, occurred_at = %s,
                    direction = %s, version = version + 1
                WHERE id = %s
                RETURNING version;
                """,
                (new_category_id, new_note, new_amount, new_occurred, new_direction, str(tx_id)),
            )
            new_version = cur.fetchone()["version"]

            # Update tags if provided
            if req.tag_ids is not None:
                cur.execute(
                    f"DELETE FROM {schema}.transaction_tags WHERE transaction_id = %s AND user_id = %s;",
                    (str(tx_id), u_id),
                )
                if req.tag_ids:
                    cur.execute(
                        f"""
                        SELECT id FROM {schema}.tags
                        WHERE user_id = %s AND category_id = %s AND id = ANY(%s::uuid[]);
                        """,
                        (u_id, new_category_id, req.tag_ids),
                    )
                    valid_tags = {str(r["id"]) for r in cur.fetchall()}
                    if len(valid_tags) != len(req.tag_ids):
                        raise HTTPException(status_code=400, detail="Tag không thuộc danh mục này")
                    for t_id in req.tag_ids:
                        cur.execute(
                            f"INSERT INTO {schema}.transaction_tags (user_id, transaction_id, tag_id) VALUES (%s, %s, %s);",
                            (u_id, str(tx_id), t_id),
                        )

            # Increment user revision
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                (u_id,),
            )
        conn.commit()

    return {"message": "Cập nhật giao dịch thành công", "version": new_version}


def delete_transaction(tx_id: uuid.UUID, user_id: uuid.UUID) -> None:
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"DELETE FROM {schema}.transactions WHERE id = %s AND user_id = %s;",
                (str(tx_id), u_id),
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")
            # Increment user revision
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                (u_id,),
            )
        conn.commit()


def get_period_reports(start_date: str, end_date: str, user_id: uuid.UUID) -> dict:
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Aggregate income and expenses excluding debt_principal
            cur.execute(
                f"""
                SELECT
                    COALESCE(SUM(CASE WHEN direction = 'income' THEN amount_vnd ELSE 0 END), 0) as total_income,
                    COALESCE(SUM(CASE WHEN direction = 'expense' THEN amount_vnd ELSE 0 END), 0) as total_expense
                FROM {schema}.transactions
                WHERE user_id = %s
                  AND occurred_at >= %s::timestamptz
                  AND occurred_at <= %s::timestamptz
                  AND purpose != 'debt_principal';
                """,
                (u_id, start_date, end_date),
            )
            row = cur.fetchone()
            total_income = row["total_income"]
            total_expense = row["total_expense"]
            difference = total_income - total_expense

            # Group by category for breakdown
            cur.execute(
                f"""
                SELECT c.id, c.name, c.icon, c.direction, SUM(t.amount_vnd) as amount_vnd
                FROM {schema}.transactions t
                JOIN {schema}.categories c ON t.category_id = c.id
                WHERE t.user_id = %s
                  AND t.occurred_at >= %s::timestamptz
                  AND t.occurred_at <= %s::timestamptz
                  AND t.purpose != 'debt_principal'
                GROUP BY c.id, c.name, c.icon, c.direction
                ORDER BY amount_vnd DESC;
                """,
                (u_id, start_date, end_date),
            )
            cat_rows = cur.fetchall()

    return {
        "total_income": str(total_income),
        "total_expense": str(total_expense),
        "difference": str(difference),
        "categories": [
            {
                "id": str(r["id"]),
                "name": r["name"],
                "icon": r["icon"],
                "direction": r["direction"],
                "amount_vnd": str(r["amount_vnd"]),
            }
            for r in cat_rows
        ],
    }


def list_transactions(
    user_id: uuid.UUID,
    direction: str | None = None,
    category_id: uuid.UUID | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[dict]:
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT t.id, t.direction, t.amount_vnd, t.occurred_at, t.source,
                       t.bank_code_snapshot, t.owner_account_snapshot, t.bank_description,
                       t.category_id, c.name as category_name, c.icon as category_icon,
                       t.user_note, t.purpose, t.version,
                       COALESCE(ARRAY_AGG(tt.tag_id) FILTER (WHERE tt.tag_id IS NOT NULL), '{{}}') as tag_ids
                FROM {schema}.transactions t
                JOIN {schema}.categories c ON t.category_id = c.id
                LEFT JOIN {schema}.transaction_tags tt ON t.id = tt.transaction_id
                WHERE t.user_id = %s
                  AND (%s::text IS NULL OR t.direction = %s)
                  AND (%s::uuid IS NULL OR t.category_id = %s::uuid)
                  AND (%s::timestamptz IS NULL OR t.occurred_at >= %s::timestamptz)
                  AND (%s::timestamptz IS NULL OR t.occurred_at <= %s::timestamptz)
                GROUP BY t.id, c.name, c.icon
                ORDER BY t.occurred_at DESC, t.id DESC
                LIMIT %s OFFSET %s;
                """,
                (
                    u_id,
                    direction,
                    direction,
                    str(category_id) if category_id else None,
                    str(category_id) if category_id else None,
                    start_date,
                    start_date,
                    end_date,
                    end_date,
                    limit,
                    offset,
                ),
            )
            rows = cur.fetchall()

    return [
        {
            "id": str(r["id"]),
            "direction": r["direction"],
            "amount_vnd": str(r["amount_vnd"]),
            "occurred_at": r["occurred_at"].isoformat(),
            "source": r["source"],
            "bank_code_snapshot": r["bank_code_snapshot"],
            "owner_account_snapshot": r["owner_account_snapshot"],
            "bank_description": r["bank_description"],
            "category_id": str(r["category_id"]),
            "category_name": r["category_name"],
            "category_icon": r["category_icon"],
            "user_note": r["user_note"],
            "purpose": r["purpose"],
            "version": r["version"],
            "tag_ids": [str(t) for t in r["tag_ids"]],
        }
        for r in rows
    ]


def get_transaction(tx_id: uuid.UUID, user_id: uuid.UUID) -> dict:
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT t.id, t.direction, t.amount_vnd, t.occurred_at, t.source,
                       t.bank_code_snapshot, t.owner_account_snapshot, t.bank_description,
                       t.category_id, c.name as category_name, c.icon as category_icon,
                       t.user_note, t.purpose, t.version,
                       COALESCE(ARRAY_AGG(tt.tag_id) FILTER (WHERE tt.tag_id IS NOT NULL), '{{}}') as tag_ids
                FROM {schema}.transactions t
                JOIN {schema}.categories c ON t.category_id = c.id
                LEFT JOIN {schema}.transaction_tags tt ON t.id = tt.transaction_id
                WHERE t.id = %s AND t.user_id = %s
                GROUP BY t.id, c.name, c.icon;
                """,
                (str(tx_id), u_id),
            )
            r = cur.fetchone()
            if not r:
                raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")

    return {
        "id": str(r["id"]),
        "direction": r["direction"],
        "amount_vnd": str(r["amount_vnd"]),
        "occurred_at": r["occurred_at"].isoformat(),
        "source": r["source"],
        "bank_code_snapshot": r["bank_code_snapshot"],
        "owner_account_snapshot": r["owner_account_snapshot"],
        "bank_description": r["bank_description"],
        "category_id": str(r["category_id"]),
        "category_name": r["category_name"],
        "category_icon": r["category_icon"],
        "user_note": r["user_note"],
        "purpose": r["purpose"],
        "version": r["version"],
        "tag_ids": [str(t) for t in r["tag_ids"]],
    }

