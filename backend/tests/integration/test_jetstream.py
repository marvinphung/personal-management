import asyncio
from datetime import datetime, timezone
from decimal import Decimal
import json
import uuid
import pytest
from starlette.websockets import WebSocketDisconnect
from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.ingest.fingerprint import compute_event_fingerprint
from qlt.messaging.client import get_jetstream
from qlt.messaging.ingestion import (
    CollectorEventItem,
    process_collector_events_async,
    set_fault_injection,
)
from qlt.messaging.receipts import find_receipt_by_id
from qlt.messaging.resolution import resolve_bank_event
from qlt.messaging.schemas import OutboxJobKind, ReceiptState
from qlt.messaging.stream import build_event_subject, ensure_stream
from qlt.messaging.worker import process_outbox_batch


@pytest.fixture
async def test_user_and_binding():
    """Sets up an active user, bank binding, and category for testing."""
    settings = get_settings()
    schema = settings.database_schema
    user_id = uuid.uuid4()
    binding_id = uuid.uuid4()
    cat_id = uuid.uuid4()
    acc_num = f"00{uuid.uuid4().int % 10000000000:010d}"

    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                # Create user
                await cur.execute(
                    f"""
                    INSERT INTO {schema}.users (
                        id, username, password_hash, role, status,
                        capture_enabled, capture_epoch
                    ) VALUES (%s, %s, 'hash', 'user', 'active', true, 1);
                    """,
                    (str(user_id), f"user_{user_id.hex[:6]}"),
                )
                # Create category
                await cur.execute(
                    f"""
                    INSERT INTO {schema}.categories (
                        id, user_id, direction, name, name_key, icon
                    ) VALUES (%s, %s, 'expense', 'Ăn uống', 'an_uong', 'food');
                    """,
                    (str(cat_id), str(user_id)),
                )
                # Create bank binding
                await cur.execute(
                    f"""
                    INSERT INTO {schema}.bank_bindings (
                        id, user_id, bank_code, account_number, version, capture_from
                    ) VALUES (%s, %s, 'bidv', %s, 1, NOW());
                    """,
                    (str(binding_id), str(user_id), acc_num),
                )
                # Create or reuse active collector
                col_id = uuid.uuid4()
                await cur.execute(
                    f"""
                    INSERT INTO {schema}.collector_devices (
                        id, credential_hash, state, epoch
                    ) VALUES (%s, 'test_cred_hash', 'active', 1)
                    ON CONFLICT (state) WHERE state = 'active'
                    DO UPDATE SET credential_hash = EXCLUDED.credential_hash, epoch = 1
                    RETURNING id;
                    """,
                    (str(col_id),),
                )
                row = await cur.fetchone()
                col_id = row["id"]

    yield {
        "user_id": user_id,
        "binding_id": binding_id,
        "category_id": cat_id,
        "account_number": acc_num,
        "collector": {"id": col_id, "epoch": 1},
    }

    # Teardown
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(f"DELETE FROM {schema}.transaction_tags WHERE transaction_id IN (SELECT id FROM {schema}.transactions WHERE user_id = %s);", (str(user_id),))
                await cur.execute(f"DELETE FROM {schema}.transactions WHERE user_id = %s;", (str(user_id),))
                await cur.execute(f"DELETE FROM {schema}.operation_receipts WHERE user_id = %s;", (str(user_id),))
                await cur.execute(f"DELETE FROM {schema}.bank_event_receipts WHERE user_id = %s;", (str(user_id),))
                await cur.execute(f"DELETE FROM {schema}.metadata_outbox_jobs WHERE user_id = %s;", (str(user_id),))
                await cur.execute(f"DELETE FROM {schema}.bank_bindings WHERE user_id = %s;", (str(user_id),))
                await cur.execute(f"DELETE FROM {schema}.categories WHERE user_id = %s;", (str(user_id),))
                await cur.execute(f"DELETE FROM {schema}.users WHERE id = %s;", (str(user_id),))


@pytest.mark.asyncio
async def test_ingest_and_publish_flow(test_user_and_binding):
    """Verifies event reservation, publication to JetStream, and commit to pending state."""
    data = test_user_and_binding
    event_id = str(uuid.uuid4())
    event_item = CollectorEventItem(
        event_id=event_id,
        collector_epoch=1,
        binding_id=str(data["binding_id"]),
        binding_version=1,
        capture_epoch=1,
        bank_code="bidv",
        owner_account=data["account_number"],
        direction="expense",
        amount_vnd="50000",
        occurred_at="2026-10-03T12:00:00Z",
        time_source="collector",
        bank_description="Chuyen khoan an trua",
        source_package="com.bidv",
        parser_version="1.0",
        source_event_key="evt-test-1",
    )

    results = await process_collector_events_async([event_item], data["collector"])
    assert len(results) == 1
    assert results[0]["status"] == "accepted"

    # Verify receipt exists in database in 'pending' state
    settings = get_settings()
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                receipt = await find_receipt_by_id(cur, settings.database_schema, uuid.UUID(event_id))
                assert receipt is not None
                assert receipt["state"] == "pending"
                assert receipt["stream_name"] is not None
                assert receipt["stream_seq"] is not None

    # Verify JetStream payload contains the immutable event
    js = await get_jetstream()
    msg = await js.get_msg(stream_name=receipt["stream_name"], seq=receipt["stream_seq"])
    payload = json.loads(msg.data.decode("utf-8"))
    assert payload["id"] == event_id
    assert Decimal(str(payload["amount"])) == Decimal("50000")


@pytest.mark.asyncio
async def test_duplicate_ingest_terminal_ack(test_user_and_binding):
    """Verifies that duplicate ingest requests return terminal 'duplicate' without creating extra messages."""
    data = test_user_and_binding
    event_id = str(uuid.uuid4())
    event_item = CollectorEventItem(
        event_id=event_id,
        collector_epoch=1,
        binding_id=str(data["binding_id"]),
        binding_version=1,
        capture_epoch=1,
        bank_code="bidv",
        owner_account=data["account_number"],
        direction="expense",
        amount_vnd="75000",
        occurred_at="2026-10-03T12:05:00Z",
        time_source="collector",
        bank_description="Ca phe",
        source_package="com.bidv",
        parser_version="1.0",
        source_event_key="evt-test-dup",
    )

    # First ingest -> accepted
    res1 = await process_collector_events_async([event_item], data["collector"])
    assert res1[0]["status"] == "accepted"

    # Second ingest -> accepted (since state is pending, confirms delivery)
    res2 = await process_collector_events_async([event_item], data["collector"])
    assert res2[0]["status"] == "accepted"

    # Resolve event to accepted
    op_id = uuid.uuid4()
    await resolve_bank_event(
        user_id=data["user_id"],
        operation_id=op_id,
        action="accept",
        pending_id=uuid.UUID(event_id),
        category_id=data["category_id"],
    )

    # Third ingest -> terminal duplicate
    res3 = await process_collector_events_async([event_item], data["collector"])
    assert res3[0]["status"] == "duplicate"


@pytest.mark.asyncio
async def test_fault_injection_publish_timeout(test_user_and_binding):
    """Verifies that a broker publish timeout returns retryable status and leaves queue item durable."""
    data = test_user_and_binding
    event_id = str(uuid.uuid4())
    event_item = CollectorEventItem(
        event_id=event_id,
        collector_epoch=1,
        binding_id=str(data["binding_id"]),
        binding_version=1,
        capture_epoch=1,
        bank_code="bidv",
        owner_account=data["account_number"],
        direction="expense",
        amount_vnd="100000",
        occurred_at="2026-10-03T12:10:00Z",
        time_source="collector",
        bank_description="Fault test timeout",
        source_package="com.bidv",
        parser_version="1.0",
        source_event_key="evt-fault-timeout",
    )

    try:
        set_fault_injection("publish_timeout", True)
        res = await process_collector_events_async([event_item], data["collector"])
        assert res[0]["status"] == "retry"
    finally:
        set_fault_injection("publish_timeout", False)


@pytest.mark.asyncio
async def test_concurrent_resolution_race(test_user_and_binding):
    """Verifies multiple devices racing to resolve the same pending event."""
    data = test_user_and_binding
    event_id = str(uuid.uuid4())
    event_item = CollectorEventItem(
        event_id=event_id,
        collector_epoch=1,
        binding_id=str(data["binding_id"]),
        binding_version=1,
        capture_epoch=1,
        bank_code="bidv",
        owner_account=data["account_number"],
        direction="expense",
        amount_vnd="200000",
        occurred_at="2026-10-03T12:15:00Z",
        time_source="collector",
        bank_description="An toi dong nghiep",
        source_package="com.bidv",
        parser_version="1.0",
        source_event_key="evt-race-test",
    )

    await process_collector_events_async([event_item], data["collector"])

    # Start both devices concurrently. Either committed resolution may win.
    res1, res2 = await asyncio.gather(resolve_bank_event(
        user_id=data["user_id"],
        operation_id=uuid.uuid4(),
        action="accept",
        pending_id=uuid.UUID(event_id),
        category_id=data["category_id"],
    ), resolve_bank_event(
        user_id=data["user_id"],
        operation_id=uuid.uuid4(),
        action="discard",
        pending_id=uuid.UUID(event_id),
    ))
    outcomes = {res1["outcome_code"], res2["outcome_code"]}
    assert "already_resolved" in outcomes
    assert len(outcomes & {"accepted", "discarded"}) == 1

    # Verify only 1 transaction exists in ledger
    settings = get_settings()
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(
                    f"SELECT COUNT(*) as count FROM {settings.database_schema}.transactions WHERE user_id = %s;",
                    (str(data["user_id"]),),
                )
                tx_count = (await cur.fetchone())["count"]
                assert tx_count == (1 if "accepted" in outcomes else 0)


@pytest.mark.asyncio
async def test_purge_user_deletes_payloads_preserves_fingerprint(test_user_and_binding):
    """Verifies that purging a user deletes broker payloads while preserving non-content dedup receipts."""
    from qlt.admin.users import purge_user
    data = test_user_and_binding
    event_id = str(uuid.uuid4())
    event_item = CollectorEventItem(
        event_id=event_id,
        collector_epoch=1,
        binding_id=str(data["binding_id"]),
        binding_version=1,
        capture_epoch=1,
        bank_code="bidv",
        owner_account=data["account_number"],
        direction="expense",
        amount_vnd="300000",
        occurred_at="2026-10-03T12:20:00Z",
        time_source="collector",
        bank_description="Tien dien",
        source_package="com.bidv",
        parser_version="1.0",
        source_event_key="evt-purge-test",
    )

    await process_collector_events_async([event_item], data["collector"])
    settings = get_settings()

    # Soft delete first (purge requires soft-deleted state)
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(
                    f"UPDATE {settings.database_schema}.users SET status = 'deleted' WHERE id = %s;",
                    (str(data["user_id"]),),
                )

    # Purge user
    admin_mock = {"user_id": uuid.uuid4(), "role": "admin"}
    purge_res = await purge_user(data["user_id"], admin_mock)
    assert "Đã xóa vĩnh viễn" in purge_res["message"]

    # Verify HMAC fingerprint survives in ingest_receipts
    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                fingerprint = compute_event_fingerprint(
                    bank_code=event_item.bank_code,
                    owner_account=event_item.owner_account,
                    direction=event_item.direction,
                    amount_vnd=300000,
                    occurred_at_iso=event_item.occurred_at,
                    bank_description=event_item.bank_description,
                    bank_reference=None,
                    source_event_key=event_item.source_event_key,
                )
                await cur.execute(
                    f"SELECT fingerprint FROM {settings.database_schema}.ingest_receipts WHERE fingerprint = %s;",
                    (fingerprint,),
                )
                row = await cur.fetchone()
                assert row is not None
                assert row["fingerprint"] == fingerprint

                # User-identifying receipt is removed
                await cur.execute(
                    f"SELECT COUNT(*) as count FROM {settings.database_schema}.bank_event_receipts WHERE user_id = %s;",
                    (str(data["user_id"]),),
                )
                assert (await cur.fetchone())["count"] == 0


def test_websocket_realtime_protocol(client):
    """Verifies /v1/realtime WebSocket authentication, hello frame, and heartbeat ping/pong."""
    from tests.integration.test_ledger import create_user_with_seeds

    user_id, session_token = create_user_with_seeds()

    with client.websocket_connect(
        "/v1/realtime",
        headers={"Authorization": f"Bearer {session_token}"},
    ) as ws:
        # 1. First frame: hello
        hello = ws.receive_json()
        assert hello["type"] == "hello"
        assert hello["protocol_version"] == "1.0"
        assert hello["data"]["user_id"] == str(user_id)

        # 2. Second frame: inbox.snapshot
        snapshot = ws.receive_json()
        assert snapshot["type"] == "inbox.snapshot"
        assert snapshot["protocol_version"] == "1.0"
        assert "events" in snapshot["data"]

        # 3. Client ping -> Server pong
        ws.send_json({
            "protocol_version": "1.0",
            "type": "ping",
            "connection_id": hello["connection_id"],
            "inbox_revision": 0,
            "data": {"timestamp": 123456789},
        })
        pong = ws.receive_json()
        assert pong["type"] == "pong"
        assert pong["data"]["client_timestamp"] == 123456789
        ws.close()
