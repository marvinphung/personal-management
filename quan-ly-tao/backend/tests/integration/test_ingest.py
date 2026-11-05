import uuid
import psycopg
from qlt.auth.sessions import hash_token
from qlt.config import get_settings


def create_collector_and_user_binding(account_number: str | None = None):
    settings = get_settings()
    collector_id = uuid.uuid4()
    collector_token = f"collector_token_{uuid.uuid4().hex}"
    cred_hash = hash_token(collector_token)

    user_id = uuid.uuid4()
    binding_id = uuid.uuid4()
    acc_num = account_number or f"00{uuid.uuid4().int % 10000000000:010d}"

    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            # Create active collector
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.collector_devices (
                    id, credential_hash, state, epoch
                ) VALUES (%s, %s, 'active', 1)
                ON CONFLICT (state) WHERE state = 'active'
                DO UPDATE SET credential_hash = EXCLUDED.credential_hash, epoch = 1
                RETURNING id;
                """,
                (str(collector_id), cred_hash),
            )
            col_id = cur.fetchone()[0]

            # Create active user with capture enabled
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.users (
                    id, username, password_hash, role, status, capture_enabled, capture_epoch
                ) VALUES (%s, %s, 'hash', 'user', 'active', true, 1);
                """,
                (str(user_id), f"u_{user_id.hex[:8]}"),
            )

            # Create bank binding
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.bank_bindings (
                    id, user_id, bank_code, account_number, version, capture_from
                ) VALUES (%s, %s, 'bidv', %s, 1, NOW());
                """,
                (str(binding_id), str(user_id), acc_num),
            )

    return collector_token, user_id, binding_id, acc_num


def test_ingest_accepted_and_deduplication(client):
    collector_token, user_id, binding_id, acc_num = create_collector_and_user_binding()
    headers = {"Authorization": f"Bearer {collector_token}"}

    # 1. Ingest event
    event_id_1 = str(uuid.uuid4())
    event_payload_1 = {
        "event_id": event_id_1,
        "collector_epoch": 1,
        "binding_id": str(binding_id),
        "binding_version": 1,
        "capture_epoch": 1,
        "bank_code": "bidv",
        "owner_account": acc_num,
        "direction": "income",
        "amount_vnd": "720000",
        "occurred_at": "2026-10-02T15:20:15Z",
        "time_source": "bank_text",
        "bank_description": "Nguyen Van B chuyen tien",
        "bank_reference": "REF-001",
        "source_package": "com.vnpay.bidv",
        "parser_version": "bidv-v2",
        "source_event_key": "sbn-001",
    }

    resp1 = client.post("/v1/collector/events", json=[event_payload_1], headers=headers)
    assert resp1.status_code == 200
    res1 = resp1.json()
    assert len(res1) == 1
    assert res1[0]["event_id"] == event_id_1
    assert res1[0]["status"] == "accepted"

    # 2. Resubmitting same event (duplicate) returns terminal duplicate ACK
    event_id_retry = str(uuid.uuid4())
    event_payload_1["event_id"] = event_id_retry
    resp2 = client.post("/v1/collector/events", json=[event_payload_1], headers=headers)
    assert resp2.status_code == 200
    res2 = resp2.json()
    assert len(res2) == 1
    assert res2[0]["status"] == "duplicate"

    # 3. Distinct event with same amount but different reference / timestamp is accepted
    event_id_2 = str(uuid.uuid4())
    event_payload_2 = dict(event_payload_1)
    event_payload_2["event_id"] = event_id_2
    event_payload_2["occurred_at"] = "2026-10-02T15:24:40Z"
    event_payload_2["bank_reference"] = "REF-002"
    event_payload_2["source_event_key"] = "sbn-002"

    resp3 = client.post("/v1/collector/events", json=[event_payload_2], headers=headers)
    assert resp3.status_code == 200
    res3 = resp3.json()
    assert res3[0]["status"] == "accepted"
