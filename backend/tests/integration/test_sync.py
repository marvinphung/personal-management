import uuid
import pytest
from qlt.auth.passwords import hash_password
from qlt.auth.sessions import create_session
from qlt.catalog.seeds import seed_user_defaults
from qlt.config import get_settings
import psycopg


def setup_user():
    settings = get_settings()
    user_id = uuid.uuid4()
    username = f"user_{user_id.hex[:8]}"
    pwd_hash = hash_password("Pass12345!")

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
        seed_user_defaults(conn, user_id)

    token, _ = create_session(user_id, scope="user")
    return user_id, token


def test_snapshot_sync_and_unchanged_response(client):
    user_id, token = setup_user()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Initial snapshot fetch
    snap1 = client.get("/v1/sync/snapshot", headers=headers)
    assert snap1.status_code == 200
    data1 = snap1.json()
    assert data1["status"] == "snapshot"
    rev1 = data1["revision"]
    assert rev1 >= 1
    assert len(data1["categories"]) >= 10
    assert len(data1["tags"]) >= 10

    # 2. Fetch with known_revision -> unchanged response
    snap2 = client.get(f"/v1/sync/snapshot?known_revision={rev1}", headers=headers)
    assert snap2.status_code == 200
    assert snap2.json()["status"] == "unchanged"
    assert snap2.json()["revision"] == rev1


def test_sync_operations_batch_lifecycle_and_canonical_mapping(client):
    user_id, token = setup_user()
    headers = {"Authorization": f"Bearer {token}"}

    client_cat_id = str(uuid.uuid4())
    client_tag_id = str(uuid.uuid4())
    client_tx_id = str(uuid.uuid4())

    op1_id = str(uuid.uuid4())
    op2_id = str(uuid.uuid4())
    op3_id = str(uuid.uuid4())

    # 1. Batch operations: create category, create tag, create manual transaction
    batch_req = {
        "operations": [
            {
                "operation_id": op1_id,
                "type": "create_category",
                "payload": {
                    "id": client_cat_id,
                    "direction": "expense",
                    "name": "Nuôi Mèo",
                    "icon": "pets",
                },
            },
            {
                "operation_id": op2_id,
                "type": "create_tag",
                "payload": {
                    "id": client_tag_id,
                    "category_id": client_cat_id,
                    "name": "Pate",
                },
            },
            {
                "operation_id": op3_id,
                "type": "create_transaction",
                "payload": {
                    "id": client_tx_id,
                    "direction": "expense",
                    "amount_vnd": "80000",
                    "occurred_at": "2026-10-03T14:00:00Z",
                    "category_id": client_cat_id,
                    "tag_ids": [client_tag_id],
                    "user_note": "Hạt và pate cho mèo",
                    "purpose": "normal",
                },
            },
        ]
    }

    res = client.post("/v1/sync/operations", json=batch_req, headers=headers)
    assert res.status_code == 200
    results = res.json()["results"]
    assert len(results) == 3
    assert all(r["status"] == "success" for r in results)

    # 2. Replay batch with identical payloads -> all replayed without error
    replay_res = client.post("/v1/sync/operations", json=batch_req, headers=headers)
    assert replay_res.status_code == 200
    replay_results = replay_res.json()["results"]
    assert all(r["replayed"] is True for r in replay_results)

    # 3. Duplicate category creation returns canonical resolution
    dup_op_id = str(uuid.uuid4())
    dup_res = client.post(
        "/v1/sync/operations",
        json={
            "operations": [
                {
                    "operation_id": dup_op_id,
                    "type": "create_category",
                    "payload": {
                        "id": str(uuid.uuid4()),
                        "direction": "expense",
                        "name": "  nuôi mèo  ",
                    },
                }
            ]
        },
        headers=headers,
    )
    assert dup_res.status_code == 200
    dup_result = dup_res.json()["results"][0]
    assert dup_result["status"] == "success"
    assert dup_result["outcome_code"] == "canonical_resolved"
    assert dup_result["canonical_id"] == client_cat_id

    # 4. Version conflict handling on update_transaction
    conflict_op_id = str(uuid.uuid4())
    conflict_res = client.post(
        "/v1/sync/operations",
        json={
            "operations": [
                {
                    "operation_id": conflict_op_id,
                    "type": "update_transaction",
                    "payload": {
                        "transaction_id": client_tx_id,
                        "base_version": 999,  # Mismatched base version!
                        "user_note": "Ghi chú xung đột",
                    },
                }
            ]
        },
        headers=headers,
    )
    assert conflict_res.status_code == 200
    c_result = conflict_res.json()["results"][0]
    assert c_result["status"] == "conflict"
    assert c_result["code"] == "VERSION_CONFLICT"

    # 5. Delete transaction and verify snapshot reflects hard deletion without resurrection
    del_op_id = str(uuid.uuid4())
    del_res = client.post(
        "/v1/sync/operations",
        json={
            "operations": [
                {
                    "operation_id": del_op_id,
                    "type": "delete_transaction",
                    "payload": {"transaction_id": client_tx_id},
                }
            ]
        },
        headers=headers,
    )
    assert del_res.status_code == 200
    assert del_res.json()["results"][0]["status"] == "success"

    # Fetch new snapshot -> transaction client_tx_id must not exist
    new_snap = client.get("/v1/sync/snapshot", headers=headers).json()
    assert all(tx["id"] != client_tx_id for tx in new_snap["transactions"])
