import uuid
from datetime import datetime, timezone
import pytest
from qlt.auth.passwords import hash_password
from qlt.auth.sessions import create_session
from qlt.catalog.seeds import seed_user_defaults
from qlt.config import get_settings
import psycopg


def create_user_with_seeds():
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


def test_category_and_tag_canonical_creation(client):
    user_id, token = create_user_with_seeds()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. List seeded categories
    res = client.get("/v1/categories?direction=expense", headers=headers)
    assert res.status_code == 200
    cats = res.json()
    assert len(cats) >= 10
    names = [c["name"] for c in cats]
    assert "Ăn uống" in names
    assert "Đi lại" in names

    # 2. Concurrent/duplicate inline category creation returns canonical category
    create1 = client.post(
        "/v1/categories",
        json={"direction": "expense", "name": "  Ăn Uống  "},
        headers=headers,
    )
    assert create1.status_code == 200
    cat_an_uong_id = create1.json()["id"]

    # 3. Create tag inline, then duplicate name returns canonical tag ID
    tag_create1 = client.post(
        f"/v1/categories/{cat_an_uong_id}/tags",
        json={"name": "Cơm trưa"},
        headers=headers,
    )
    assert tag_create1.status_code == 201
    tag_id1 = tag_create1.json()["id"]

    tag_create2 = client.post(
        f"/v1/categories/{cat_an_uong_id}/tags",
        json={"name": "  cơm trưa  "},
        headers=headers,
    )
    assert tag_create2.status_code == 200
    assert tag_create2.json()["id"] == tag_id1


def test_manual_transaction_lifecycle_and_foreign_tag_rejection(client):
    user_a, token_a = create_user_with_seeds()
    user_b, token_b = create_user_with_seeds()
    headers_a = {"Authorization": f"Bearer {token_a}"}
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # User A gets category and tag
    cats_a = client.get("/v1/categories?direction=expense", headers=headers_a).json()
    cat_a = cats_a[0]
    tags_a = client.get(f"/v1/categories/{cat_a['id']}/tags", headers=headers_a).json()
    tag_a_id = tags_a[0]["id"]

    # User B gets category and tag
    cats_b = client.get("/v1/categories?direction=expense", headers=headers_b).json()
    cat_b = cats_b[0]
    tags_b = client.get(f"/v1/categories/{cat_b['id']}/tags", headers=headers_b).json()
    tag_b_id = tags_b[0]["id"]

    # Attempt to attach User B's tag to User A's transaction -> 400
    fail_tx = client.post(
        "/v1/transactions",
        json={
            "direction": "expense",
            "amount_vnd": "50000",
            "occurred_at": "2026-10-03T10:00:00Z",
            "category_id": cat_a["id"],
            "tag_ids": [tag_b_id],
            "user_note": "Hack tag",
        },
        headers=headers_a,
    )
    assert fail_tx.status_code == 400

    # User A creates valid manual transaction
    create_tx = client.post(
        "/v1/transactions",
        json={
            "direction": "expense",
            "amount_vnd": "50000",
            "occurred_at": "2026-10-03T10:00:00Z",
            "category_id": cat_a["id"],
            "tag_ids": [tag_a_id],
            "user_note": "Cà phê sáng",
        },
        headers=headers_a,
    )
    assert create_tx.status_code == 201
    tx_id = create_tx.json()["id"]

    # Fetch transaction details
    get_tx = client.get(f"/v1/transactions/{tx_id}", headers=headers_a)
    assert get_tx.status_code == 200
    assert get_tx.json()["amount_vnd"] == "50000"
    assert get_tx.json()["source"] == "manual"
    assert tag_a_id in get_tx.json()["tag_ids"]

    # Update manual transaction (financial fields and note)
    update_tx = client.patch(
        f"/v1/transactions/{tx_id}",
        json={"amount_vnd": "55000", "user_note": "Cà phê sữa"},
        headers=headers_a,
    )
    assert update_tx.status_code == 200

    # Verify updated
    get_updated = client.get(f"/v1/transactions/{tx_id}", headers=headers_a)
    assert get_updated.json()["amount_vnd"] == "55000"
    assert get_updated.json()["user_note"] == "Cà phê sữa"

    # Delete transaction
    del_tx = client.delete(f"/v1/transactions/{tx_id}", headers=headers_a)
    assert del_tx.status_code == 204

    # Verify deleted
    assert client.get(f"/v1/transactions/{tx_id}", headers=headers_a).status_code == 404


def test_bank_transaction_immutability(client):
    user_id, token = create_user_with_seeds()
    headers = {"Authorization": f"Bearer {token}"}
    settings = get_settings()

    cats = client.get("/v1/categories?direction=income", headers=headers).json()
    cat1_id = cats[0]["id"]
    cat2_id = cats[1]["id"]

    # Directly insert a bank transaction in database
    tx_id = uuid.uuid4()
    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.transactions (
                    id, user_id, direction, amount_vnd, occurred_at, source,
                    bank_code_snapshot, owner_account_snapshot, bank_description,
                    category_id, user_note, purpose
                ) VALUES (%s, %s, 'income', 720000, '2026-10-03T12:00:00+07:00', 'bank',
                          'bidv', '001234567890', 'BIDV NHAN TIEN', %s, '', 'normal');
                """,
                (str(tx_id), str(user_id), cat1_id),
            )

    # 1. Attempt to change amount on bank transaction -> 400 Bad Request
    fail_edit = client.patch(
        f"/v1/transactions/{tx_id}",
        json={"amount_vnd": "800000"},
        headers=headers,
    )
    assert fail_edit.status_code == 400

    # 2. Attempt to change direction on bank transaction -> 400 Bad Request
    fail_edit_dir = client.patch(
        f"/v1/transactions/{tx_id}",
        json={"direction": "expense"},
        headers=headers,
    )
    assert fail_edit_dir.status_code == 400

    # 3. Edit category and user_note only -> Success
    ok_edit = client.patch(
        f"/v1/transactions/{tx_id}",
        json={"category_id": cat2_id, "user_note": "Tiền thưởng dự án"},
        headers=headers,
    )
    assert ok_edit.status_code == 200

    # Verify financial fields remained unchanged, user note and category updated
    tx_res = client.get(f"/v1/transactions/{tx_id}", headers=headers).json()
    assert tx_res["amount_vnd"] == "720000"
    assert tx_res["category_id"] == cat2_id
    assert tx_res["user_note"] == "Tiền thưởng dự án"
    assert tx_res["bank_code_snapshot"] == "bidv"


def test_period_reports_and_principal_exclusion(client):
    user_id, token = create_user_with_seeds()
    headers = {"Authorization": f"Bearer {token}"}
    settings = get_settings()

    cats_exp = client.get("/v1/categories?direction=expense", headers=headers).json()
    cat_exp_id = cats_exp[0]["id"]
    cats_inc = client.get("/v1/categories?direction=income", headers=headers).json()
    cat_inc_id = cats_inc[0]["id"]

    # Insert transactions:
    # 1. Normal expense: 200,000 VND
    # 2. Normal income: 1,000,000 VND
    # 3. Debt principal (e.g. loan repayment): 500,000 VND -> must be EXCLUDED from period income/expense totals
    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.transactions (
                    id, user_id, direction, amount_vnd, occurred_at, source, category_id, purpose
                ) VALUES
                (%s, %s, 'expense', 200000, '2026-10-01T10:00:00Z', 'manual', %s, 'normal'),
                (%s, %s, 'income', 1000000, '2026-10-02T10:00:00Z', 'manual', %s, 'normal'),
                (%s, %s, 'expense', 500000, '2026-10-02T15:00:00Z', 'manual', %s, 'debt_principal');
                """,
                (
                    str(uuid.uuid4()), str(user_id), cat_exp_id,
                    str(uuid.uuid4()), str(user_id), cat_inc_id,
                    str(uuid.uuid4()), str(user_id), cat_exp_id,
                ),
            )

    report_res = client.get(
        "/v1/reports/period?start_date=2026-10-01T00:00:00Z&end_date=2026-10-03T23:59:59Z",
        headers=headers,
    )
    assert report_res.status_code == 200
    report = report_res.json()

    assert report["total_income"] == "1000000"
    assert report["total_expense"] == "200000"  # 500k debt principal excluded!
    assert report["difference"] == "800000"
