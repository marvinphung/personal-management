import uuid

import pytest
from fastapi import HTTPException

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.client import get_jetstream
from qlt.messaging.inbox import get_user_inbox_events
from qlt.messaging.ingestion import process_collector_events_async, set_fault_injection
from qlt.messaging.reconcile import recover_stuck_publishing_receipts
from qlt.messaging.resolution import resolve_bank_event
from tests.integration.test_jetstream_recovery import event_for, receipt_for

pytest_plugins = ["tests.integration.test_jetstream"]


async def test_snapshot_revision_drift_is_retryable_not_mislabeled(test_user_and_binding, monkeypatch):
    import qlt.messaging.inbox as inbox
    data = test_user_and_binding
    event = event_for(data)
    await process_collector_events_async([event], data["collector"])
    real_fetch = inbox.fetch_single_payload

    async def fetch_then_mutate(*args, **kwargs):
        payload = await real_fetch(*args, **kwargs)
        async with get_async_connection() as conn:
            async with conn.cursor() as cur:
                await cur.execute("UPDATE qlt.user_revisions SET inbox_revision=inbox_revision+1 WHERE user_id=%s", (data["user_id"],))
            await conn.commit()
        return payload

    monkeypatch.setattr(inbox, "fetch_single_payload", fetch_then_mutate)
    with pytest.raises(HTTPException) as exc:
        await get_user_inbox_events(data["user_id"], max_retries=2)
    assert exc.value.status_code == 503


async def test_recovery_after_crash_and_terminal_not_resurrected(test_user_and_binding):
    data = test_user_and_binding
    event = event_for(data)
    set_fault_injection("crash_after_publish", True)
    try:
        assert (await process_collector_events_async([event], data["collector"]))[0]["status"] == "retry"
    finally:
        set_fault_injection("crash_after_publish", False)
    assert (await receipt_for(event))["state"] == "publishing"
    assert await recover_stuck_publishing_receipts(max_age_seconds=0) >= 1
    assert (await receipt_for(event))["state"] == "pending"
    await resolve_bank_event(data["user_id"], uuid.uuid4(), "discard", uuid.UUID(event.event_id))
    await recover_stuck_publishing_receipts(max_age_seconds=0)
    assert (await receipt_for(event))["state"] == "discarded"


async def test_purge_cleans_lost_ack_without_sequence(test_user_and_binding):
    from nats.js.errors import NotFoundError

    from qlt.admin.users import purge_user
    from qlt.messaging.stream import build_event_subject
    data = test_user_and_binding
    event = event_for(data)
    set_fault_injection("crash_after_publish", True)
    try:
        await process_collector_events_async([event], data["collector"])
    finally:
        set_fault_injection("crash_after_publish", False)
    receipt = await receipt_for(event)
    assert receipt["stream_seq"] is None
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE qlt.users SET status='deleted' WHERE id=%s", (data["user_id"],))
        await conn.commit()
    await purge_user(data["user_id"], {"role": "admin"})
    js = await get_jetstream()
    with pytest.raises(NotFoundError):
        await js.get_msg(get_settings().get_stream_name(), subject=build_event_subject(data["user_id"], uuid.UUID(event.event_id)))


async def test_hash_mismatch_rejected_by_snapshot_and_accept(test_user_and_binding):
    data = test_user_and_binding
    event = event_for(data)
    await process_collector_events_async([event], data["collector"])
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE qlt.bank_event_receipts SET payload_hash='tampered' WHERE id=%s", (event.event_id,))
        await conn.commit()
    with pytest.raises(HTTPException):
        await get_user_inbox_events(data["user_id"], max_retries=1)
    with pytest.raises(HTTPException):
        await resolve_bank_event(data["user_id"], uuid.uuid4(), "accept", uuid.UUID(event.event_id), data["category_id"])
    assert (await receipt_for(event))["state"] == "pending"


async def test_concurrent_same_operation_replays_success(test_user_and_binding):
    import asyncio
    data = test_user_and_binding
    event = event_for(data)
    await process_collector_events_async([event], data["collector"])
    op = uuid.uuid4()
    first, second = await asyncio.gather(
        resolve_bank_event(data["user_id"], op, "accept", uuid.UUID(event.event_id), data["category_id"]),
        resolve_bank_event(data["user_id"], op, "accept", uuid.UUID(event.event_id), data["category_id"]),
    )
    assert first["transaction_id"] == second["transaction_id"]
    assert {first["replayed"], second["replayed"]} == {False, True}


async def test_coordinator_does_not_recover_stale_capture_epoch(test_user_and_binding):
    data = test_user_and_binding
    event = event_for(data)
    set_fault_injection("crash_after_publish", True)
    try:
        await process_collector_events_async([event], data["collector"])
    finally:
        set_fault_injection("crash_after_publish", False)
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE qlt.users SET capture_epoch=capture_epoch+2 WHERE id=%s", (data["user_id"],))
        await conn.commit()
    await recover_stuck_publishing_receipts(max_age_seconds=0)
    assert (await receipt_for(event))["state"] == "purged"
    assert (await get_user_inbox_events(data["user_id"]))[1] == []
