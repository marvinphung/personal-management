from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from qlt.auth.dependencies import require_admin_user
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1/admin/banks", tags=["Admin Banks"])


class BankSettingUpdateRequest(BaseModel):
    enabled: bool = True
    receiver_account: str | None = None
    receiver_name: str | None = None
    instructions: str | None = None


@router.get("")
def list_bank_settings(admin: dict = Depends(require_admin_user)):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT bank_code, enabled, receiver_account, receiver_name, instructions, version
                FROM {settings.database_schema}.bank_settings
                ORDER BY bank_code ASC;
                """
            )
            rows = cur.fetchall()
    return [dict(r) for r in rows]


@router.put("/{bank_code}")

def update_bank_setting(
    bank_code: str,
    req: BankSettingUpdateRequest,
    admin: dict = Depends(require_admin_user),
):
    code = bank_code.strip().lower()
    settings = get_settings()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.bank_settings
                SET enabled = %s,
                    receiver_account = %s,
                    receiver_name = %s,
                    instructions = %s,
                    version = version + 1
                WHERE bank_code = %s
                RETURNING bank_code, enabled, receiver_account, receiver_name, instructions, version;
                """,
                (req.enabled, req.receiver_account, req.receiver_name, req.instructions, code),
            )
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Không tìm thấy ngân hàng")
        conn.commit()

    return dict(row)
