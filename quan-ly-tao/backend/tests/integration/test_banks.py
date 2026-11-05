import uuid
from qlt.auth.passwords import hash_password
from qlt.auth.sessions import create_session
from qlt.config import get_settings
import psycopg


def create_active_user():
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
    token, _ = create_session(user_id, scope="user")
    return user_id, token


def test_bank_linking_and_conflict_handling(client):
    user_a, token_a = create_active_user()
    user_b, token_b = create_active_user()
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # 1. Get supported banks (should only include bidv, vietinbank, vietcombank, techcombank; no mbbank)
    banks_resp = client.get("/v1/banks", headers=headers_a)
    assert banks_resp.status_code == 200
    bank_codes = [b["bank_code"] for b in banks_resp.json()]
    assert "bidv" in bank_codes
    assert "vietinbank" in bank_codes
    assert "vietcombank" in bank_codes
    assert "techcombank" in bank_codes
    assert "mbbank" not in bank_codes

    # 2. User A links account with leading zeros
    acc_num = f"00{uuid.uuid4().int % 10000000000:010d}"
    bind_resp_a = client.post(
        "/v1/bank-bindings",
        json={"bank_code": "bidv", "account_number": acc_num},
        headers=headers_a,
    )
    assert bind_resp_a.status_code == 201
    binding_id = bind_resp_a.json()["id"]
    assert bind_resp_a.json()["account_number"] == acc_num

    # 3. User B tries to link the same account at the same bank -> 409 ACCOUNT_ALREADY_REGISTERED
    bind_resp_b = client.post(
        "/v1/bank-bindings",
        json={"bank_code": "bidv", "account_number": acc_num},
        headers=headers_b,
    )
    assert bind_resp_b.status_code == 409
    assert bind_resp_b.json()["code"] == "ACCOUNT_ALREADY_REGISTERED"
    assert "đã được đăng ký" in bind_resp_b.json()["message"]

    # 4. User A updates account number -> version increments
    acc_num_updated = f"00{uuid.uuid4().int % 10000000000:010d}"
    update_resp = client.patch(
        f"/v1/bank-bindings/{binding_id}",
        json={"account_number": acc_num_updated},
        headers=headers_a,
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["version"] == 2
    assert update_resp.json()["account_number"] == acc_num_updated
