import uuid
from datetime import datetime, timezone
import pytest
from qlt.auth.passwords import hash_password
from qlt.auth.sessions import create_session
from qlt.catalog.seeds import seed_user_defaults
from qlt.config import get_settings
import psycopg


def setup_user_and_pending_event(direction="expense", amount_vnd=150000):
    settings = get_settings()
    user_id = uuid.uuid4()
    username = f"user_{user_id.hex[:8]}"
    pwd_hash = hash_password("Pass12345!")
    pending_id = uuid.uuid4()
    fingerprint = f"fp_{uuid.uuid4().hex}"

    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.users (
                    id, username, password_hash, role, status
                ) VALUES (%s, %s, %s, 'user', 'active');
                """,
                (str(user_id), username, pwd_hash),
            )
            # Ingest receipt
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.ingest_receipts (
                    fingerprint, algorithm_version
                ) VALUES (%s, 'v1');
                """,
                (fingerprint,),
            )
            # Pending bank event
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.pending_bank_events (
                    id, user_id, bank_code, owner_account_snapshot, amount_vnd,
                    direction, occurred_at, time_source, bank_description,
                    fingerprint, parser_version
                ) VALUES (%s, %s, 'bidv', '001234567890', %s, %s, NOW(), 'bank',
                          'BIDV-GD MUA SAM', %s, 'v1');
                """,
                (str(pending_id), str(user_id), amount_vnd, direction, fingerprint),
            )
        seed_user_defaults(conn, user_id)

    token, _ = create_session(user_id, scope="user")
    return user_id, token, pending_id


def test_atomic_accept_and_financial_field_protection(client):
    user_id, token, pending_id = setup_user_and_pending_event(direction="expense", amount_vnd=250000)
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Fetch user categories to pick an expense category
    cats = client.get("/v1/categories?direction=expense", headers=headers).json()
    cat_id = cats[0]["id"]
    tags = client.get(f"/v1/categories/{cat_id}/tags", headers=headers).json()
    tag_id = tags[0]["id"]

    op_id = str(uuid.uuid4())

    # 2. Accept pending event
    accept_resp = client.post(
        f"/v1/pending-events/{pending_id}/accept",
        json={
            "operation_id": op_id,
            "category_id": cat_id,
            "tag_ids": [tag_id],
            "user_note": "Đi siêu thị",
            # Even if a malicious client passes altered financial fields, they are ignored
            "amount_vnd": "999999999",
            "direction": "income",
        },
        headers=headers,
    )
    assert accept_resp.status_code == 200
    tx_id = accept_resp.json()["transaction_id"]
    assert accept_resp.json()["replayed"] is False

    # 3. Verify transaction created with exact bank fields from database
    tx_resp = client.get(f"/v1/transactions/{tx_id}", headers=headers)
    assert tx_resp.status_code == 200
    tx = tx_resp.json()
    assert tx["amount_vnd"] == "250000"  # Protected from DB!
    assert tx["direction"] == "expense"   # Protected from DB!
    assert tx["source"] == "bank"
    assert tx["bank_code_snapshot"] == "bidv"
    assert tx["category_id"] == cat_id
    assert tag_id in tx["tag_ids"]
    assert tx["user_note"] == "Đi siêu thị"

    # 4. Verify pending event is deleted from inbox
    pending_list = client.get("/v1/pending-events", headers=headers).json()
    assert all(p["id"] != str(pending_id) for p in pending_list)

    # 5. Operation replay with identical payload -> 200 replayed
    replay_resp = client.post(
        f"/v1/pending-events/{pending_id}/accept",
        json={
            "operation_id": op_id,
            "category_id": cat_id,
            "tag_ids": [tag_id],
            "user_note": "Đi siêu thị",
        },
        headers=headers,
    )
    assert replay_resp.status_code == 200
    assert replay_resp.json()["replayed"] is True
    assert replay_resp.json()["transaction_id"] == tx_id

    # 6. Mismatched request reuse of the same operation_id -> 409 Conflict
    mismatch_resp = client.post(
        f"/v1/pending-events/{pending_id}/accept",
        json={
            "operation_id": op_id,
            "category_id": cat_id,
            "tag_ids": [],
            "user_note": "Ghi chú khác",
        },
        headers=headers,
    )
    assert mismatch_resp.status_code == 409


def test_atomic_discard(client):
    user_id, token, pending_id = setup_user_and_pending_event(direction="income", amount_vnd=500000)
    headers = {"Authorization": f"Bearer {token}"}
    op_id = str(uuid.uuid4())

    # 1. Discard the pending event
    discard_resp = client.post(
        f"/v1/pending-events/{pending_id}/discard",
        json={"operation_id": op_id},
        headers=headers,
    )
    assert discard_resp.status_code == 200
    assert discard_resp.json()["replayed"] is False

    # 2. Verify pending event deleted
    pending_list = client.get("/v1/pending-events", headers=headers).json()
    assert all(p["id"] != str(pending_id) for p in pending_list)

    # 3. Verify NO transaction was created
    txs = client.get("/v1/transactions", headers=headers).json()
    assert len(txs) == 0

    # 4. Replay discard -> 200 replayed
    replay_resp = client.post(
        f"/v1/pending-events/{pending_id}/discard",
        json={"operation_id": op_id},
        headers=headers,
    )
    assert replay_resp.status_code == 200
    assert replay_resp.json()["replayed"] is True


def test_accept_direction_mismatch_rejected(client):
    # Setup expense event
    user_id, token, pending_id = setup_user_and_pending_event(direction="expense", amount_vnd=100000)
    headers = {"Authorization": f"Bearer {token}"}

    # Pick an income category
    income_cats = client.get("/v1/categories?direction=income", headers=headers).json()
    inc_cat_id = income_cats[0]["id"]

    # Try to accept expense event with income category -> 422
    res = client.post(
        f"/v1/pending-events/{pending_id}/accept",
        json={
            "operation_id": str(uuid.uuid4()),
            "category_id": inc_cat_id,
        },
        headers=headers,
    )
    assert res.status_code == 422
