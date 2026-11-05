from fastapi import APIRouter, Depends, status
from pydantic import BaseModel

from qlt.auth.dependencies import require_active_user
from qlt.push.service import PushRegistrationRequest, register_push_device, revoke_push_device

router = APIRouter(prefix="/v1/push", tags=["Push Notifications"])


class RevokeDeviceRequest(BaseModel):
    device_id: str


@router.post("/register", status_code=status.HTTP_200_OK)
async def register_device(
    req: PushRegistrationRequest,
    user: dict = Depends(require_active_user),
):
    await register_push_device(
        user_id=user["user_id"],
        platform=req.platform,
        device_id=req.device_id,
        token=req.token,
        environment=req.environment,
    )
    return {"status": "ok"}


@router.delete("/revoke", status_code=status.HTTP_200_OK)
async def revoke_device(
    req: RevokeDeviceRequest,
    user: dict = Depends(require_active_user),
):
    await revoke_push_device(
        user_id=user["user_id"],
        device_id=req.device_id,
    )
    return {"status": "ok"}
