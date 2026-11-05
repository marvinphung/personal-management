import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, status
from qlt.auth.dependencies import require_active_user
from qlt.ledger.service import (
    TransactionCreateRequest,
    TransactionUpdateRequest,
    create_manual_transaction,
    delete_transaction,
    get_period_reports,
    get_transaction,
    list_transactions,
    update_transaction,
)

router = APIRouter(prefix="/v1", tags=["Ledger"])


@router.post("/transactions", status_code=status.HTTP_201_CREATED)
def create_transaction_endpoint(
    req: TransactionCreateRequest,
    user: dict = Depends(require_active_user),
):
    return create_manual_transaction(req, user["user_id"])


@router.get("/transactions")
def list_transactions_endpoint(
    direction: str | None = Query(None, pattern="^(income|expense)$"),
    category_id: uuid.UUID | None = Query(None),
    start_date: str | None = Query(None),
    end_date: str | None = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: dict = Depends(require_active_user),
):
    return list_transactions(
        user_id=user["user_id"],
        direction=direction,
        category_id=category_id,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
        offset=offset,
    )


@router.get("/transactions/{transaction_id}")
def get_transaction_endpoint(
    transaction_id: uuid.UUID,
    user: dict = Depends(require_active_user),
):
    return get_transaction(transaction_id, user["user_id"])


@router.patch("/transactions/{transaction_id}")
def update_transaction_endpoint(
    transaction_id: uuid.UUID,
    req: TransactionUpdateRequest,
    user: dict = Depends(require_active_user),
):
    return update_transaction(transaction_id, req, user["user_id"])


@router.delete("/transactions/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction_endpoint(
    transaction_id: uuid.UUID,
    user: dict = Depends(require_active_user),
):
    delete_transaction(transaction_id, user["user_id"])
    return None


@router.get("/reports/period")
def get_period_reports_endpoint(
    start_date: str = Query(..., description="ISO datetime start boundary"),
    end_date: str = Query(..., description="ISO datetime end boundary"),
    user: dict = Depends(require_active_user),
):
    return get_period_reports(start_date, end_date, user["user_id"])
