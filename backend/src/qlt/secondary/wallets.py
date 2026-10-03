import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from qlt.auth.dependencies import require_active_user
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1/wallets/cash", tags=["Cash Wallet"])


class CashAdjustmentRequest(BaseModel):
    new_balance_vnd: str  # New desired balance integer string
    note: str = ""


@router.get("")
def get_cash_wallet(user: dict = Depends(require_active_user)):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. Fetch or initialize wallet
            cur.execute(
                f"SELECT id, name, opening_amount_vnd, version FROM {schema}.cash_wallets WHERE user_id = %s;",
                (u_id,),
            )
            wallet = cur.fetchone()
            if not wallet:
                wallet_id = uuid.uuid4()
                cur.execute(
                    f"""
                    INSERT INTO {schema}.cash_wallets (id, user_id, name, opening_amount_vnd)
                    VALUES (%s, %s, 'Ví tiền mặt', 0)
                    RETURNING id, name, opening_amount_vnd, version;
                    """,
                    (str(wallet_id), u_id),
                )
                wallet = cur.fetchone()
                conn.commit()

            w_id = str(wallet["id"])
            opening = wallet["opening_amount_vnd"]

            # 2. Sum of cash adjustments
            cur.execute(
                f"SELECT COALESCE(SUM(delta_vnd), 0) as total_adj FROM {schema}.cash_adjustments WHERE wallet_id = %s;",
                (w_id,),
            )
            total_adj = cur.fetchone()["total_adj"]

            # 3. Sum of cash transactions
            cur.execute(
                f"""
                SELECT
                    COALESCE(SUM(CASE WHEN direction = 'income' THEN amount_vnd ELSE -amount_vnd END), 0) as tx_delta
                FROM {schema}.transactions
                WHERE user_id = %s AND cash_wallet_id = %s;
                """,
                (u_id, w_id),
            )
            tx_delta = cur.fetchone()["tx_delta"]

            current_balance = opening + total_adj + tx_delta

    return {
        "id": w_id,
        "name": wallet["name"],
        "balance_vnd": str(current_balance),
        "opening_amount_vnd": str(opening),
    }


@router.post("/adjust", status_code=status.HTTP_200_OK)
def adjust_cash_balance(req: CashAdjustmentRequest, user: dict = Depends(require_active_user)):
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user["user_id"])

    target_balance = int(req.new_balance_vnd)
    if target_balance < 0:
        raise HTTPException(status_code=422, detail="Số dư không thể âm")

    with get_connection() as conn:
        with conn.cursor() as cur:
            # 1. Fetch wallet
            cur.execute(
                f"SELECT id, opening_amount_vnd FROM {schema}.cash_wallets WHERE user_id = %s FOR UPDATE;",
                (u_id,),
            )
            wallet = cur.fetchone()
            if not wallet:
                wallet_id = uuid.uuid4()
                cur.execute(
                    f"""
                    INSERT INTO {schema}.cash_wallets (id, user_id, name, opening_amount_vnd)
                    VALUES (%s, %s, 'Ví tiền mặt', 0)
                    RETURNING id, opening_amount_vnd;
                    """,
                    (str(wallet_id), u_id),
                )
                wallet = cur.fetchone()

            w_id = str(wallet["id"])
            opening = wallet["opening_amount_vnd"]

            # Current balance
            cur.execute(
                f"SELECT COALESCE(SUM(delta_vnd), 0) as total_adj FROM {schema}.cash_adjustments WHERE wallet_id = %s;",
                (w_id,),
            )
            total_adj = cur.fetchone()["total_adj"]

            cur.execute(
                f"""
                SELECT
                    COALESCE(SUM(CASE WHEN direction = 'income' THEN amount_vnd ELSE -amount_vnd END), 0) as tx_delta
                FROM {schema}.transactions
                WHERE user_id = %s AND cash_wallet_id = %s;
                """,
                (u_id, w_id),
            )
            tx_delta = cur.fetchone()["tx_delta"]

            current = opening + total_adj + tx_delta
            delta = target_balance - current

            if delta != 0:
                cur.execute(
                    f"INSERT INTO {schema}.cash_adjustments (wallet_id, user_id, delta_vnd) VALUES (%s, %s, %s);",
                    (w_id, u_id, delta),
                )
                cur.execute(
                    f"UPDATE {schema}.user_revisions SET revision = revision + 1 WHERE user_id = %s;",
                    (u_id,),
                )
        conn.commit()

    return {
        "wallet_id": w_id,
        "new_balance_vnd": str(target_balance),
        "adjustment_delta_vnd": str(delta),
    }
