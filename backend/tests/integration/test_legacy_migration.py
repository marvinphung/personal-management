import uuid

from qlt.db import get_async_connection
from qlt.messaging.client import get_jetstream
from qlt.messaging.inbox import get_user_inbox_events
from qlt.messaging.migrate_pending import migrate_pending_events
from qlt.messaging.stream import ensure_stream

pytest_plugins = ["tests.integration.test_jetstream"]


async def test_legacy_migration_preserves_id_and_replays_without_duplicate(test_user_and_binding):
    data = test_user_and_binding
    event_id, fingerprint = uuid.uuid4(), uuid.uuid4().hex
    await ensure_stream(await get_jetstream())
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("INSERT INTO qlt.ingest_receipts (fingerprint,algorithm_version) VALUES (%s,'v1')", (fingerprint,))
            await cur.execute("""INSERT INTO qlt.pending_bank_events
                (id,user_id,binding_id,bank_code,owner_account_snapshot,amount_vnd,direction,
                 occurred_at,time_source,bank_description,fingerprint,parser_version)
                VALUES (%s,%s,%s,'bidv',%s,50000,'expense',NOW(),'bank_text','Legacy event',%s,'1')""",
                (event_id, data["user_id"], data["binding_id"], data["account_number"], fingerprint))
        await conn.commit()
    dry = await migrate_pending_events(dry_run=True)
    assert dry["migrated"] == 0
    await migrate_pending_events()
    _, events = await get_user_inbox_events(data["user_id"])
    assert len(events) == 1 and events[0]["id"] == str(event_id)
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT stream_seq FROM qlt.bank_event_receipts WHERE id=%s", (event_id,))
            seq = (await cur.fetchone())["stream_seq"]
    await migrate_pending_events()
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT stream_seq FROM qlt.bank_event_receipts WHERE id=%s", (event_id,))
            assert (await cur.fetchone())["stream_seq"] == seq
