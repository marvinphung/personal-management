import uuid

from qlt.db import get_connection
from qlt.messaging.ingestion import CollectorEventItem, process_collector_events_async
from qlt.messaging.worker import process_outbox_batch
from tests.integration.test_ledger import create_user_with_seeds


def test_new_bank_event_delivered_over_websocket(client):
    user_id, session_token = create_user_with_seeds()
    binding_id = uuid.uuid4()
    account = f"00{uuid.uuid4().int % 10000000000:010d}"
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO qlt.bank_bindings (id,user_id,bank_code,account_number,version) VALUES (%s,%s,'bidv',%s,1)",
                (binding_id, user_id, account))
        conn.commit()
    event = CollectorEventItem(event_id=str(uuid.uuid4()), collector_epoch=1,
        binding_id=str(binding_id), binding_version=1, capture_epoch=1, bank_code="bidv",
        owner_account=account, direction="expense", amount_vnd="12345",
        occurred_at="2026-10-04T12:00:00Z", time_source="collector", bank_description="Live delivery",
        source_package="com.bidv", parser_version="1", source_event_key=str(uuid.uuid4()))
    with client.websocket_connect("/v1/realtime", headers={"Authorization": f"Bearer {session_token}"}) as ws:
        assert ws.receive_json()["type"] == "hello"
        assert ws.receive_json()["data"]["events"] == []
        result = client.portal.call(process_collector_events_async, [event], {"epoch": 1})
        assert result[0]["status"] == "accepted"
        client.portal.call(process_outbox_batch, "test-realtime", 10000)
        frame = ws.receive_json()
        assert frame["type"] == "inbox.snapshot"
        assert len(frame["data"]["events"]) == 1
        assert frame["data"]["events"][0]["id"] == event.event_id
        assert frame["data"]["events"][0]["amount_vnd"] == "12345"
        # Also exercises synchronous snapshot bridge on the owning lifespan loop.
        response = client.get("/v1/sync/snapshot", headers={"Authorization": f"Bearer {session_token}"})
        assert response.status_code == 200
        assert response.json()["pending_bank_events"][0]["id"] == event.event_id
        operation = {"operations": [{"operation_id": str(uuid.uuid4()),
            "type": "discard_pending", "payload": {"pending_id": event.event_id}}]}
        headers = {"Authorization": f"Bearer {session_token}"}
        resolved = client.post("/v1/sync/operations", json=operation, headers=headers)
        assert resolved.json()["results"][0]["status"] == "success"
        replay = client.post("/v1/sync/operations", json=operation, headers=headers)
        assert replay.json()["results"][0]["replayed"] is True
