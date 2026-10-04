import asyncio
import uuid
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.client import get_jetstream
from qlt.messaging.ingestion import CollectorEventItem, process_collector_events_async
from qlt.messaging.receipts import commit_receipt_pending, find_receipt_by_id
from qlt.messaging.resolution import resolve_bank_event
from qlt.messaging.stream import build_event_subject, ensure_stream

pytest_plugins = ["tests.integration.test_jetstream"]


def event_for(data):
    return CollectorEventItem(
        event_id=str(uuid.uuid4()), collector_epoch=1,
        binding_id=str(data["binding_id"]), binding_version=1, capture_epoch=1,
        bank_code="bidv", owner_account=data["account_number"], direction="expense",
        amount_vnd="50000", occurred_at="2026-10-04T12:00:00Z", time_source="collector",
        bank_description="Recovery test", source_package="com.bidv", parser_version="1",
        source_event_key=str(uuid.uuid4()),
    )


async def receipt_for(event):
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            return await find_receipt_by_id(cur, get_settings().database_schema, uuid.UUID(event.event_id))


async def test_terminal_receipt_cannot_be_recommitted(test_user_and_binding):
    data = test_user_and_binding
    event = event_for(data)
    assert (await process_collector_events_async([event], data["collector"]))[0]["status"] == "accepted"
    before = await receipt_for(event)
    await resolve_bank_event(data["user_id"], uuid.uuid4(), "discard", uuid.UUID(event.event_id))
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                result = await commit_receipt_pending(cur, get_settings().database_schema,
                    uuid.UUID(event.event_id), data["user_id"], before["stream_name"], before["stream_seq"])
                assert result is None
    assert (await receipt_for(event))["state"] == "discarded"


async def test_purge_broker_down_keeps_user_and_metadata(test_user_and_binding, monkeypatch):
    from qlt.admin.users import purge_user
    data = test_user_and_binding
    event = event_for(data)
    await process_collector_events_async([event], data["collector"])
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE qlt.users SET status='deleted' WHERE id=%s", (data["user_id"],))
        await conn.commit()
    monkeypatch.setattr("qlt.messaging.client.get_jetstream", AsyncMock(side_effect=ConnectionError()))
    with pytest.raises(HTTPException) as exc:
        await purge_user(data["user_id"], {"role": "admin"})
    assert exc.value.status_code == 503
    assert await receipt_for(event) is not None
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT status FROM qlt.users WHERE id=%s", (data["user_id"],))
            assert (await cur.fetchone())["status"] == "deleted"


async def test_lost_publish_ack_retry_reuses_stored_payload(test_user_and_binding, monkeypatch):
    data = test_user_and_binding
    event = event_for(data)
    js = await get_jetstream()
    await ensure_stream(js)
    real_publish = js.publish

    async def store_then_timeout(*args, **kwargs):
        await real_publish(*args, **kwargs)
        raise asyncio.TimeoutError()

    monkeypatch.setattr(js, "publish", store_then_timeout)
    assert (await process_collector_events_async([event], data["collector"]))[0]["status"] == "retry"
    subject = build_event_subject(data["user_id"], uuid.UUID(event.event_id))
    original = await js.get_msg(get_settings().get_stream_name(), subject=subject)
    monkeypatch.setattr(js, "publish", AsyncMock(side_effect=AssertionError("Retry must not republish")))
    assert (await process_collector_events_async([event], data["collector"]))[0]["status"] == "accepted"
    receipt = await receipt_for(event)
    assert receipt["stream_seq"] == original.seq


async def test_publish_subject_rejects_second_message(test_user_and_binding):
    js = await get_jetstream()
    await ensure_stream(js)
    subject = build_event_subject(test_user_and_binding["user_id"], uuid.uuid4())
    await js.publish(subject, b"first")
    with pytest.raises(Exception):
        await js.publish(subject, b"second")
    msg = await js.get_msg(get_settings().get_stream_name(), subject=subject)
    assert msg.data == b"first"
    await js.delete_msg(get_settings().get_stream_name(), msg.seq)
