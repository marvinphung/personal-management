from datetime import datetime
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from qlt.auth.dependencies import require_active_user
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1", tags=["Debts & People"])


class PersonCreateRequest(BaseModel):
    name: str
    note: str | None = None


class DebtCreateRequest(BaseModel):
    person_name: str
    direction: str  # 'lent' or 'borrowed'
    principal_vnd: str  # positive integer string
    started_at: str | None = None
    due_at: str | None = None
    category_id: uuid.UUID
    note: str = ""


class DebtPaymentRequest(BaseModel):
    amount_vnd: str  # positive integer string
    paid_at: str | None = None
    category_id: uuid.UUID
    note: str = ""


@router.get("/people")
def list_people(user: dict = Depends(require_active_user)):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT id, name, note, version FROM {schema}.people WHERE user_id = %s ORDER BY name ASC;",
                (u_id,),
            )
            rows = cur.fetchall()

    return [{"id": str(r["id"]), "name": r["name"], "note": r["note"]} for r in rows]


@router.post("/people", status_code=status.HTTP_201_CREATED)
def create_person(req: PersonCreateRequest, user: dict = Depends(require_active_user)):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])
    name = req.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Tên người không được để trống")

    person_id = uuid.uuid4()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"INSERT INTO {schema}.people (id, user_id, name, note) VALUES (%s, %s, %s, %s);",
                (str(person_id), u_id, name, req.note),
            )
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                (u_id,),
            )
        conn.commit()

    return {"id": str(person_id), "name": name, "note": req.note}


@router.get("/debts")
def list_debts(user: dict = Depends(require_active_user)):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT d.id, d.direction, d.principal_vnd, d.started_at, d.due_at, d.status, d.version,
                       p.id as person_id, p.name as person_name,
                       COALESCE(SUM(dp.amount_vnd), 0) as paid_vnd
                FROM {schema}.debts d
                JOIN {schema}.people p ON d.person_id = p.id
                LEFT JOIN {schema}.debt_payments dp ON d.id = dp.debt_id
                WHERE d.user_id = %s
                GROUP BY d.id, p.id, p.name
                ORDER BY d.started_at DESC;
                """,
                (u_id,),
            )
            rows = cur.fetchall()

    return [
        {
            "id": str(r["id"]),
            "person_id": str(r["person_id"]),
            "person_name": r["person_name"],
            "direction": r["direction"],
            "principal_vnd": str(r["principal_vnd"]),
            "paid_vnd": str(r["paid_vnd"]),
            "remaining_vnd": str(r["principal_vnd"] - r["paid_vnd"]),
            "started_at": r["started_at"].isoformat(),
            "due_at": r["due_at"].isoformat() if r["due_at"] else None,
            "status": r["status"],
            "version": r["version"],
        }
        for r in rows
    ]


@router.post("/debts", status_code=status.HTTP_201_CREATED)
def create_debt(req: DebtCreateRequest, user: dict = Depends(require_active_user)):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    amount = int(req.principal_vnd)
    if amount <= 0:
        raise HTTPException(status_code=422, detail="Số tiền phải lớn hơn 0")

    started_dt = (
        datetime.fromisoformat(req.started_at.replace("Z", "+00:00"))
        if req.started_at
        else datetime.now()
    )
    due_dt = (
        datetime.fromisoformat(req.due_at.replace("Z", "+00:00"))
        if req.due_at
        else None
    )

    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. Resolve or create person
            cur.execute(
                f"SELECT id FROM {schema}.people WHERE user_id = %s AND LOWER(name) = LOWER(%s);",
                (u_id, req.person_name.strip()),
            )
            p_row = cur.fetchone()
            if p_row:
                person_id = p_row["id"]
            else:
                person_id = uuid.uuid4()
                cur.execute(
                    f"INSERT INTO {schema}.people (id, user_id, name) VALUES (%s, %s, %s);",
                    (str(person_id), u_id, req.person_name.strip()),
                )

            # 2. Create disbursement transaction (purpose='debt_principal' so excluded from ordinary reports)
            tx_direction = "expense" if req.direction == "lent" else "income"
            tx_id = uuid.uuid4()
            cur.execute(
                f"""
                INSERT INTO {schema}.transactions (
                    id, user_id, direction, amount_vnd, occurred_at, source,
                    category_id, user_note, purpose, version
                ) VALUES (%s, %s, %s, %s, %s, 'manual', %s, %s, 'debt_principal', 1)
                RETURNING id;
                """,
                (
                    str(tx_id),
                    u_id,
                    tx_direction,
                    amount,
                    started_dt,
                    str(req.category_id),
                    req.note,
                ),
            )

            # 3. Create debt record
            debt_id = uuid.uuid4()
            cur.execute(
                f"""
                INSERT INTO {schema}.debts (
                    id, user_id, person_id, direction, principal_vnd, started_at, due_at, status
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'active');
                """,
                (str(debt_id), u_id, str(person_id), req.direction, amount, started_dt, due_dt),
            )

            # 4. Link disbursement
            cur.execute(
                f"INSERT INTO {schema}.debt_disbursements (user_id, debt_id, transaction_id) VALUES (%s, %s, %s);",
                (u_id, str(debt_id), str(tx_id)),
            )

            # 5. Increment user revision
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                (u_id,),
            )
        conn.commit()

    return {
        "id": str(debt_id),
        "person_id": str(person_id),
        "person_name": req.person_name.strip(),
        "direction": req.direction,
        "principal_vnd": str(amount),
        "remaining_vnd": str(amount),
        "transaction_id": str(tx_id),
    }


@router.post("/debts/{debt_id}/payments", status_code=status.HTTP_201_CREATED)
def record_debt_payment(
    debt_id: uuid.UUID,
    req: DebtPaymentRequest,
    user: dict = Depends(require_active_user),
):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    amount = int(req.amount_vnd)
    if amount <= 0:
        raise HTTPException(status_code=422, detail="Số tiền thanh toán phải lớn hơn 0")

    paid_dt = (
        datetime.fromisoformat(req.paid_at.replace("Z", "+00:00"))
        if req.paid_at
        else datetime.now()
    )

    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. Fetch debt
            cur.execute(
                f"SELECT * FROM {schema}.debts WHERE id = %s AND user_id = %s FOR UPDATE;",
                (str(debt_id), u_id),
            )
            debt = cur.fetchone()
            if not debt:
                raise HTTPException(status_code=404, detail="Không tìm thấy khoản nợ")

            # 2. Repayment direction is opposite of debt disbursement:
            # If lent (cho vay), collection is 'income'. If borrowed (vay), repayment is 'expense'.
            tx_direction = "income" if debt["direction"] == "lent" else "expense"

            tx_id = uuid.uuid4()
            cur.execute(
                f"""
                INSERT INTO {schema}.transactions (
                    id, user_id, direction, amount_vnd, occurred_at, source,
                    category_id, user_note, purpose, version
                ) VALUES (%s, %s, %s, %s, %s, 'manual', %s, %s, 'debt_principal', 1)
                RETURNING id;
                """,
                (str(tx_id), u_id, tx_direction, amount, paid_dt, str(req.category_id), req.note),
            )

            # 3. Insert debt payment
            pmt_id = uuid.uuid4()
            cur.execute(
                f"""
                INSERT INTO {schema}.debt_payments (
                    id, user_id, debt_id, amount_vnd, paid_at, transaction_id
                ) VALUES (%s, %s, %s, %s, %s, %s);
                """,
                (str(pmt_id), u_id, str(debt_id), amount, paid_dt, str(tx_id)),
            )

            # 4. Check if settled
            cur.execute(
                f"SELECT COALESCE(SUM(amount_vnd), 0) as total_paid FROM {schema}.debt_payments WHERE debt_id = %s;",
                (str(debt_id),),
            )
            total_paid = cur.fetchone()["total_paid"]
            if total_paid >= debt["principal_vnd"]:
                cur.execute(
                    f"UPDATE {schema}.debts SET status = 'settled' WHERE id = %s;",
                    (str(debt_id),),
                )

            # 5. Increment user revision
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                (u_id,),
            )
        conn.commit()

    return {
        "id": str(pmt_id),
        "debt_id": str(debt_id),
        "amount_vnd": str(amount),
        "remaining_vnd": str(max(0, debt["principal_vnd"] - total_paid)),
        "transaction_id": str(tx_id),
    }
