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


from qlt.messaging.inbox import get_user_inbox_events


@router.get("/pending-events")
async def list_pending_events(
    user: dict = Depends(require_active_user),
):
    _, events = await get_user_inbox_events(user["user_id"])
    return events


from qlt.messaging.resolution import resolve_bank_event


@router.post("/pending-events/{pending_id}/accept", status_code=status.HTTP_200_OK)
async def accept_pending_event(
    pending_id: uuid.UUID,
    req: AcceptPendingRequest,
    user: dict = Depends(require_active_user),
):
    return await resolve_bank_event(
        user_id=user["user_id"],
        operation_id=req.operation_id,
        action="accept",
        pending_id=pending_id,
        category_id=req.category_id,
        tag_ids=req.tag_ids,
        user_note=req.user_note,
        purpose=req.purpose,
    )


@router.post("/pending-events/{pending_id}/discard", status_code=status.HTTP_200_OK)
async def discard_pending_event(
    pending_id: uuid.UUID,
    req: DiscardPendingRequest,
    user: dict = Depends(require_active_user),
):
    return await resolve_bank_event(
        user_id=user["user_id"],
        operation_id=req.operation_id,
        action="discard",
        pending_id=pending_id,
    )
