import asyncio
import logging
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from nats.js.errors import NotFoundError
from pydantic import BaseModel

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.ingest.fingerprint import compute_event_fingerprint
from qlt.messaging.client import get_jetstream
from qlt.messaging.integrity import verified_payload
from qlt.messaging.outbox import enqueue_outbox_job
from qlt.messaging.receipts import (
    commit_receipt_pending,
    compute_payload_hash,
    find_receipt_by_fingerprint,
    lock_receipt_by_id,
    reserve_receipt,
)
from qlt.messaging.schemas import BankEventPayload, OutboxJobKind
from qlt.messaging.stream import build_event_msg_id, build_event_subject

logger = logging.getLogger(__name__)
FAULT_INJECTION_HOOKS = {"publish_timeout": False, "crash_after_publish": False, "crash_before_commit": False}


def set_fault_injection(hook: str, enabled: bool) -> None:
    if hook in FAULT_INJECTION_HOOKS:
        FAULT_INJECTION_HOOKS[hook] = enabled


class CollectorEventItem(BaseModel):
    event_id: str
    collector_epoch: int
    binding_id: str
    binding_version: int
    capture_epoch: int
    bank_code: str
    owner_account: str
    direction: str
    amount_vnd: str
    occurred_at: str
    time_source: str
    bank_description: str
    bank_reference: str | None = None
    source_package: str
    parser_version: str
    source_event_key: str


async def locked_binding(cur, schema, ev):
    # Resolve owner without a lock, then explicitly acquire user before binding.
    # A joined FOR SHARE does not guarantee PostgreSQL's row-mark lock order.
    await cur.execute(f"SELECT user_id FROM {schema}.bank_bindings WHERE id=%s", (ev.binding_id,))
    owner = await cur.fetchone()
    if not owner:
        return None, "BINDING_NOT_FOUND"
    await cur.execute(
        f"SELECT status,capture_enabled,capture_epoch FROM {schema}.users WHERE id=%s FOR SHARE",
        (owner["user_id"],),
    )
    user = await cur.fetchone()
    if not user or user["status"] != "active" or not user["capture_enabled"]:
        return None, "USER_CAPTURE_DISABLED"
    await cur.execute(
        f"""SELECT id,user_id,version,capture_from FROM {schema}.bank_bindings
        WHERE id=%s AND user_id=%s AND bank_code=%s AND account_number=%s FOR SHARE""",
        (ev.binding_id, owner["user_id"], ev.bank_code, ev.owner_account),
    )
    row = await cur.fetchone()
    if not row:
        return None, "BINDING_NOT_FOUND"
    if ev.capture_epoch != user["capture_epoch"] or ev.binding_version != row["version"]:
        return None, "STALE_CAPTURE_EPOCH"
    return row, None


async def lock_revision(cur, schema, user_id):
    await cur.execute(
        f"""INSERT INTO {schema}.user_revisions (user_id,revision,inbox_revision)
        VALUES (%s,0,0) ON CONFLICT (user_id) DO UPDATE
        SET revision={schema}.user_revisions.revision""", (str(user_id),),
    )


async def pending_notifications(cur, schema, receipt, stream_name, stream_seq):
    rev = await commit_receipt_pending(cur, schema, receipt["id"], receipt["user_id"], stream_name, stream_seq)
    if rev is None:
        return False
    await cur.execute(f"UPDATE {schema}.user_revisions SET revision=revision+1 WHERE user_id=%s", (receipt["user_id"],))
    await cur.execute(f"UPDATE {schema}.bank_bindings SET first_received_at=COALESCE(first_received_at,NOW()) WHERE id=%s", (receipt["binding_id"],))
    for kind in (OutboxJobKind.REALTIME_INVALIDATION, OutboxJobKind.PUSH_REFRESH):
        await enqueue_outbox_job(cur, schema, kind, receipt["user_id"], receipt["id"], stream_name, stream_seq, rev)
    return True


async def process_single_event(ev, collector_epoch, schema) -> dict[str, Any]:
    def result(status, reason=None):
        return {"event_id": ev.event_id, "status": status, **({"reason": reason} if reason else {})}

    if ev.collector_epoch != collector_epoch:
        return result("dropped", "STALE_COLLECTOR_EPOCH")
    try:
        amount = Decimal(ev.amount_vnd)
        event_id = uuid.UUID(ev.event_id)
        uuid.UUID(ev.binding_id)
        occurred = datetime.fromisoformat(ev.occurred_at.replace("Z", "+00:00"))
        if (not amount.is_finite() or amount <= 0 or amount != amount.to_integral_value()
                or amount > 9223372036854775807 or ev.direction not in ("income", "expense")
                or occurred.tzinfo is None):
            raise ValueError()
    except (ValueError, ArithmeticError):
        return result("dropped", "INVALID_FORMAT")

    fingerprint = compute_event_fingerprint(
        bank_code=ev.bank_code, owner_account=ev.owner_account, direction=ev.direction,
        amount_vnd=int(amount), occurred_at_iso=ev.occurred_at, bank_description=ev.bank_description,
        bank_reference=ev.bank_reference, source_event_key=ev.source_event_key,
    )
    settings = get_settings()
    try:
        # Commit the reservation first so a broker ACK lost to a crash is recoverable.
        async with get_async_connection() as conn:
            async with conn.transaction():
                async with conn.cursor() as cur:
                    binding, reason = await locked_binding(cur, schema, ev)
                    if reason:
                        return result("dropped", reason)
                    user_id = binding["user_id"]
                    await lock_revision(cur, schema, user_id)
                    existing = await find_receipt_by_fingerprint(cur, schema, fingerprint)
                    if existing:
                        if existing["state"] in ("accepted", "discarded", "purged"):
                            return result("duplicate")
                        if existing["state"] == "pending":
                            return result("accepted" if str(existing["id"]) == ev.event_id else "duplicate")
                        event_id = existing["id"]
                    payload = BankEventPayload(
                        id=event_id, user_id=user_id, binding_id=binding["id"], source_type=ev.bank_code,
                        account_number_mask=f"...{ev.owner_account[-4:]}", amount=amount,
                        direction=ev.direction, booking_time=occurred, transaction_code=ev.bank_reference,
                        raw_description=ev.bank_description,
                        raw_payload={"source_package": ev.source_package, "parser_version": ev.parser_version,
                                     "time_source": ev.time_source},
                        created_at=occurred,
                    )
                    if not existing:
                        # A hard-purged HMAC still suppresses old collector events.
                        await cur.execute(f"SELECT fingerprint FROM {schema}.ingest_receipts WHERE fingerprint=%s", (fingerprint,))
                        if await cur.fetchone():
                            return result("duplicate")
                        await reserve_receipt(cur, schema, event_id, user_id, binding["id"], fingerprint,
                                              compute_payload_hash(payload.model_dump()), ev.capture_epoch, ev.binding_version)
                    else:
                        # Older reservations have unknown fencing until the original
                        # collector retry proves its epochs still match current routing.
                        await cur.execute(f"""UPDATE {schema}.bank_event_receipts
                            SET capture_epoch=COALESCE(capture_epoch,%s),
                                binding_version=COALESCE(binding_version,%s)
                            WHERE id=%s""", (ev.capture_epoch, ev.binding_version, event_id))

        # Hold fencing and receipt locks across a bounded broker operation. Purge and
        # resolution cannot pass this phase while a publish is still in flight.
        async with get_async_connection() as conn:
            async with conn.transaction():
                async with conn.cursor() as cur:
                    binding, reason = await locked_binding(cur, schema, ev)
                    if reason:
                        return result("dropped", reason)
                    await lock_revision(cur, schema, user_id)
                    receipt = await lock_receipt_by_id(cur, schema, event_id)
                    if not receipt:
                        return result("dropped", "RECEIPT_REMOVED")
                    if receipt["state"] != "publishing":
                        return result("accepted" if receipt["state"] == "pending" else "duplicate")
                    if receipt["capture_epoch"] != ev.capture_epoch or receipt["binding_version"] != ev.binding_version:
                        return result("dropped", "STALE_RESERVATION")
                    js = await get_jetstream()
                    stream = settings.get_stream_name()
                    subject = build_event_subject(user_id, event_id)
                    try:
                        msg = await js.get_msg(stream, subject=subject)
                        verified_payload(msg, receipt)
                        seq = msg.seq
                    except NotFoundError:
                        if compute_payload_hash(payload.model_dump()) != receipt["payload_hash"]:
                            return result("retry", "PAYLOAD_MISMATCH")
                        if FAULT_INJECTION_HOOKS["publish_timeout"]:
                            return result("retry", "FAULT_INJECTED_TIMEOUT")
                        ack = await asyncio.wait_for(js.publish(subject, payload.model_dump_json().encode(),
                            headers={"Nats-Msg-Id": build_event_msg_id(event_id)}), settings.nats_publish_timeout_seconds)
                        seq = ack.seq
                        if ack.stream != stream:
                            raise ValueError("Unexpected stream acknowledgment")
                    if FAULT_INJECTION_HOOKS["crash_after_publish"] or FAULT_INJECTION_HOOKS["crash_before_commit"]:
                        return result("retry", "FAULT_INJECTED_CRASH_AFTER_PUBLISH")
                    await pending_notifications(cur, schema, receipt, stream, seq)
        return result("accepted")
    except Exception as exc:
        logger.warning("Collector event %s deferred (%s)", ev.event_id, type(exc).__name__)
        return result("retry", "INGEST_UNAVAILABLE")


async def process_collector_events_async(events, active_collector):
    schema = get_settings().database_schema
    return [await process_single_event(ev, active_collector["epoch"], schema) for ev in events]
