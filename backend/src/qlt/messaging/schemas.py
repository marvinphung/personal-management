import uuid
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, Field


class ReceiptState(str, Enum):
    PUBLISHING = "publishing"
    PENDING = "pending"
    ACCEPTED = "accepted"
    DISCARDED = "discarded"
    PURGED = "purged"


class OutboxJobKind(str, Enum):
    PAYLOAD_CLEANUP = "payload_cleanup"
    REALTIME_INVALIDATION = "realtime_invalidation"
    PUSH_REFRESH = "push_refresh"


class OutboxJobStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class BankEventPayload(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    binding_id: uuid.UUID | None
    source_type: str
    account_number_mask: str
    amount: Decimal
    direction: str
    booking_time: datetime
    transaction_code: str | None = None
    counterparty_account: str | None = None
    counterparty_bank: str | None = None
    counterparty_name: str | None = None
    raw_description: str
    raw_payload: dict | None = None
    suggested_category_id: uuid.UUID | None = None
    suggested_tags: list[str] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    def to_inbox_dto(self) -> dict:
        """Serializes payload for mobile inbox API / WebSocket."""
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "binding_id": str(self.binding_id),
            "source_type": self.source_type,
            "account_number_mask": self.account_number_mask,
            "amount": float(self.amount),
            "direction": self.direction,
            "booking_time": self.booking_time.isoformat(),
            "transaction_code": self.transaction_code,
            "counterparty_account": self.counterparty_account,
            "counterparty_bank": self.counterparty_bank,
            "counterparty_name": self.counterparty_name,
            "raw_description": self.raw_description,
            "suggested_category_id": str(self.suggested_category_id)
            if self.suggested_category_id
            else None,
            "suggested_tags": self.suggested_tags,
            "created_at": self.created_at.isoformat(),
        }


class EventReceipt(BaseModel):
    event_id: uuid.UUID
    user_id: uuid.UUID
    binding_id: uuid.UUID
    stream_name: str | None = None
    stream_seq: int | None = None
    state: ReceiptState
    payload_hash: str
    first_received_at: datetime
    resolved_at: datetime | None = None
    discarded_at: datetime | None = None
    created_at: datetime


class OutboxJob(BaseModel):
    id: uuid.UUID
    kind: OutboxJobKind
    user_id: uuid.UUID
    event_id: uuid.UUID | None = None
    stream_name: str | None = None
    stream_seq: int | None = None
    inbox_revision: int | None = None
    attempts: int = 0
    max_attempts: int = 10
    next_attempt_at: datetime
    status: OutboxJobStatus
    last_error: str | None = None
    created_at: datetime
    completed_at: datetime | None = None
