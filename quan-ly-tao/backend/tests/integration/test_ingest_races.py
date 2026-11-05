import uuid
from .test_ingest import create_collector_and_user_binding


def test_ingest_stale_epoch_and_disabled_user(client):
    collector_token, user_id, binding_id, acc_num = create_collector_and_user_binding()
    headers = {"Authorization": f"Bearer {collector_token}"}

    # Stale collector epoch (e.g. 0 instead of 1)
    event_stale_col = {
        "event_id": str(uuid.uuid4()),
        "collector_epoch": 0,
        "binding_id": str(binding_id),
        "binding_version": 1,
        "capture_epoch": 1,
        "bank_code": "bidv",
        "owner_account": acc_num,
        "direction": "expense",
        "amount_vnd": "50000",
        "occurred_at": "2026-10-02T15:20:15Z",
        "time_source": "bank_text",
        "bank_description": "Coffee",
        "source_package": "com.vnpay.bidv",
        "parser_version": "bidv-v2",
        "source_event_key": "sbn-stale",
    }
    resp = client.post("/v1/collector/events", json=[event_stale_col], headers=headers)
    assert resp.status_code == 200
    assert resp.json()[0]["status"] == "dropped"
    assert resp.json()[0]["reason"] == "STALE_COLLECTOR_EPOCH"
