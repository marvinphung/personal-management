from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel
from qlt.auth.routes import get_current_user
from qlt.auth.sessions import (
    create_widget_token,
    revoke_widget_token,
    verify_session,
    verify_widget_token,
)
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1", tags=["Widget"])


class WidgetTokenResponse(BaseModel):
    token: str
    expires_at: str


class WidgetSummaryResponse(BaseModel):
    pending_count: int
    count: int
    pending_ids: list[str]
    captured_epoch: int


def get_widget_user(
    authorization: str | None = Header(None, alias="Authorization"),
) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "UNAUTHORIZED", "message": "Yêu cầu mã xác thực"},
        )
    token = authorization[len("Bearer ") :].strip()

    # Allow either a dedicated widget token or a regular session token
    user = verify_widget_token(token)
    if not user:
        user = verify_session(token)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "UNAUTHORIZED", "message": "Mã xác thực không hợp lệ hoặc đã hết hạn"},
        )

    if user.get("deleted_at") is not None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_DELETED", "message": "Tài khoản đã bị xóa"},
        )

    if user.get("status") not in ("approved", "active"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "USER_NOT_APPROVED", "message": "Tài khoản chưa được phê duyệt"},
        )

    return user


@router.post("/widget-token", response_model=WidgetTokenResponse)
def generate_widget_token(current_user: dict = Depends(get_current_user)):
    user_id = current_user["user_id"]
    token, expires_at = create_widget_token(uuid.UUID(str(user_id)))
    return WidgetTokenResponse(token=token, expires_at=expires_at.isoformat())


@router.delete("/widget-token")
def delete_widget_token(
    authorization: str | None = Header(None, alias="Authorization"),
    current_user: dict = Depends(get_current_user),
):
    if authorization and authorization.startswith("Bearer "):
        token = authorization[len("Bearer ") :].strip()
        revoke_widget_token(token)
    return {"status": "ok"}


@router.get("/widget/summary", response_model=WidgetSummaryResponse)
def get_widget_summary(widget_user: dict = Depends(get_widget_user)):
    user_id = str(widget_user["user_id"])
    settings = get_settings()

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Query pending bank events for this user from coordination metadata
            cur.execute(
                f"""
                SELECT id FROM {settings.database_schema}.bank_event_receipts
                WHERE user_id = %s AND state = 'pending'
                ORDER BY first_received_at DESC;
                """,
                (user_id,),
            )
            rows = cur.fetchall()
            pending_ids = [str(r["id"]) for r in rows]

    epoch = int(datetime.now(timezone.utc).timestamp())
    return WidgetSummaryResponse(
        pending_count=len(pending_ids),
        count=len(pending_ids),
        pending_ids=pending_ids,
        captured_epoch=epoch,
    )
