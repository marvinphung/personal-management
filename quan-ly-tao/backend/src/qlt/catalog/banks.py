import re
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
import psycopg
from qlt.auth.dependencies import require_active_user
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1", tags=["Banks"])

SUPPORTED_BANKS = {"bidv", "vietinbank", "vietcombank", "techcombank"}


class BankBindingCreateRequest(BaseModel):
    bank_code: str
    account_number: str


class BankBindingUpdateRequest(BaseModel):
    account_number: str


def normalize_account_number(acc: str) -> str:
    # Strip spaces and dashes, but strictly preserve leading zeros
    cleaned = re.sub(r"[\s\-]", "", acc)
    if not cleaned or not cleaned.isdigit() or len(cleaned) < 4 or len(cleaned) > 32:
        raise ValueError("Số tài khoản không hợp lệ (từ 4 đến 32 chữ số)")
    return cleaned


@router.get("/banks")
def get_banks(user: dict = Depends(require_active_user)):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT bank_code, enabled, receiver_account, receiver_name, instructions, version
                FROM {settings.database_schema}.bank_settings
                WHERE enabled = true
                ORDER BY bank_code;
                """
            )
            banks = cur.fetchall()

    return [
        {
            "bank_code": b["bank_code"],
            "enabled": b["enabled"],
            "receiver_account": b["receiver_account"],
            "receiver_name": b["receiver_name"],
            "instructions": b["instructions"] or "Chưa có hướng dẫn",
            "version": b["version"],
        }
        for b in banks
    ]


@router.get("/bank-bindings")
def get_user_bindings(user: dict = Depends(require_active_user)):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT id, user_id, bank_code, account_number, version, capture_from, first_received_at
                FROM {settings.database_schema}.bank_bindings
                WHERE user_id = %s
                ORDER BY bank_code;
                """,
                (str(user["user_id"]),),
            )
            bindings = cur.fetchall()

    return [
        {
            "id": str(b["id"]),
            "user_id": str(b["user_id"]),
            "bank_code": b["bank_code"],
            "account_number": b["account_number"],
            "version": b["version"],
            "capture_from": b["capture_from"].isoformat(),
            "first_received_at": b["first_received_at"].isoformat() if b["first_received_at"] else None,
        }
        for b in bindings
    ]


@router.post("/bank-bindings", status_code=status.HTTP_201_CREATED)
def create_binding(req: BankBindingCreateRequest, user: dict = Depends(require_active_user)):
    bank_code = req.bank_code.strip().lower()
    if bank_code not in SUPPORTED_BANKS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "UNSUPPORTED_BANK", "message": f"Ngân hàng '{bank_code}' không được hỗ trợ"},
        )

    try:
        account_number = normalize_account_number(req.account_number)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_ACCOUNT_NUMBER", "message": str(e)},
        )

    settings = get_settings()
    binding_id = uuid.uuid4()

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    INSERT INTO {settings.database_schema}.bank_bindings (
                        id, user_id, bank_code, account_number, version, capture_from
                    ) VALUES (%s, %s, %s, %s, 1, NOW())
                    RETURNING id, capture_from;
                    """,
                    (str(binding_id), str(user["user_id"]), bank_code, account_number),
                )
                row = cur.fetchone()
            conn.commit()
    except psycopg.errors.UniqueViolation as e:
        # Check if user already linked this bank or if another user has this account
        err_msg = str(e)
        if "bank_bindings_user_bank_unique" in err_msg:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"code": "BANK_ALREADY_LINKED", "message": "Bạn đã liên kết tài khoản cho ngân hàng này"},
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "ACCOUNT_ALREADY_REGISTERED", "message": "Số tài khoản này đã được đăng ký"},
        )

    return {
        "id": str(binding_id),
        "user_id": str(user["user_id"]),
        "bank_code": bank_code,
        "account_number": account_number,
        "version": 1,
        "capture_from": row["capture_from"].isoformat(),
        "first_received_at": None,
    }


@router.patch("/bank-bindings/{binding_id}")
def update_binding(
    binding_id: uuid.UUID,
    req: BankBindingUpdateRequest,
    user: dict = Depends(require_active_user),
):
    try:
        new_account = normalize_account_number(req.account_number)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "INVALID_ACCOUNT_NUMBER", "message": str(e)},
        )

    settings = get_settings()
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    UPDATE {settings.database_schema}.bank_bindings
                    SET account_number = %s, version = version + 1, capture_from = NOW(), first_received_at = NULL
                    WHERE id = %s AND user_id = %s
                    RETURNING bank_code, version, capture_from;
                    """,
                    (new_account, str(binding_id), str(user["user_id"])),
                )
                row = cur.fetchone()
                if not row:
                    raise HTTPException(status_code=404, detail="Không tìm thấy liên kết ngân hàng")
            conn.commit()
    except psycopg.errors.UniqueViolation:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "ACCOUNT_ALREADY_REGISTERED", "message": "Số tài khoản này đã được đăng ký"},
        )

    return {
        "id": str(binding_id),
        "user_id": str(user["user_id"]),
        "bank_code": row["bank_code"],
        "account_number": new_account,
        "version": row["version"],
        "capture_from": row["capture_from"].isoformat(),
        "first_received_at": None,
    }
