import json

from qlt.messaging.receipts import compute_payload_hash
from qlt.messaging.schemas import BankEventPayload
from qlt.messaging.stream import build_event_subject


def verified_payload(msg, receipt) -> BankEventPayload:
    """Never trust a broker locator without verifying tenant, event and content."""
    payload = BankEventPayload.model_validate(json.loads(msg.data))
    if (
        str(payload.id) != str(receipt["id"])
        or str(payload.user_id) != str(receipt["user_id"])
        or str(payload.binding_id) != str(receipt["binding_id"])
        or msg.subject != build_event_subject(payload.user_id, payload.id)
        or compute_payload_hash(payload.model_dump()) != receipt["payload_hash"]
    ):
        raise ValueError("Broker payload identity or hash mismatch")
    return payload
