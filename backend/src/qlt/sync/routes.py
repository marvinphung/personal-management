from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel
from qlt.auth.dependencies import require_active_user
from qlt.sync.operations import TypedOperation, execute_operations_batch
from qlt.sync.snapshot import get_user_snapshot

router = APIRouter(prefix="/v1/sync", tags=["Sync"])


class OperationsBatchRequest(BaseModel):
    operations: list[TypedOperation]


@router.get("/snapshot")
def get_snapshot_endpoint(
    known_revision: int | None = Query(None),
    user: dict = Depends(require_active_user),
):
    return get_user_snapshot(user["user_id"], known_revision=known_revision)


@router.post("/operations", status_code=status.HTTP_200_OK)
def post_operations_endpoint(
    req: OperationsBatchRequest,
    user: dict = Depends(require_active_user),
):
    results = execute_operations_batch(user["user_id"], req.operations)
    return {"results": results}
