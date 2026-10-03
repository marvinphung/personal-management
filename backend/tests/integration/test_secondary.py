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


def test_debt_lifecycle_and_principal_exclusion(client):
    user_id, token = setup_user()
    headers = {"Authorization": f"Bearer {token}"}

    cats = client.get("/v1/categories?direction=expense", headers=headers).json()
    cat_id = cats[0]["id"]

    # 1. Create a lending debt of 1,000,000 VND to "Anh Tuấn"
    create_debt_resp = client.post(
        "/v1/debts",
        json={
            "person_name": "Anh Tuấn",
            "direction": "lent",
            "principal_vnd": "1000000",
            "category_id": cat_id,
            "note": "Cho vay mua điện thoại",
        },
        headers=headers,
    )
    assert create_debt_resp.status_code == 201
    debt_data = create_debt_resp.json()
    debt_id = debt_data["id"]
    assert debt_data["principal_vnd"] == "1000000"
    assert debt_data["remaining_vnd"] == "1000000"

    # 2. Verify debt listed
    debts = client.get("/v1/debts", headers=headers).json()
    assert len(debts) == 1
    assert debts[0]["person_name"] == "Anh Tuấn"
    assert debts[0]["status"] == "active"

    # 3. Record repayment of 400,000 VND
    income_cats = client.get("/v1/categories?direction=income", headers=headers).json()
    inc_cat_id = income_cats[0]["id"]

    payment_resp = client.post(
        f"/v1/debts/{debt_id}/payments",
        json={
            "amount_vnd": "400000",
            "category_id": inc_cat_id,
            "note": "Trả đợt 1",
        },
        headers=headers,
    )
    assert payment_resp.status_code == 201
    assert payment_resp.json()["remaining_vnd"] == "600000"

    # 4. Verify debt remaining principal is updated
    debts_after = client.get("/v1/debts", headers=headers).json()
    assert debts_after[0]["remaining_vnd"] == "600000"
    assert debts_after[0]["paid_vnd"] == "400000"

    # 5. Verify that period report EXCLUDES both debt disbursement and debt repayment
    # (since their purpose is 'debt_principal')
    report = client.get(
        "/v1/reports/period?start_date=2026-01-01T00:00:00Z&end_date=2026-12-31T23:59:59Z",
        headers=headers,
    ).json()
    assert report["total_income"] == "0"
    assert report["total_expense"] == "0"


def test_cash_wallet_lifecycle_and_adjustment(client):
    user_id, token = setup_user()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Fetch cash wallet (auto-initializes with 0)
    wallet = client.get("/v1/wallets/cash", headers=headers).json()
    assert wallet["balance_vnd"] == "0"

    # 2. Adjust cash balance to 500,000 VND
    adj_resp = client.post(
        "/v1/wallets/cash/adjust",
        json={"new_balance_vnd": "500000", "note": "Rút tiền mặt"},
        headers=headers,
    )
    assert adj_resp.status_code == 200
    assert adj_resp.json()["new_balance_vnd"] == "500000"
    assert adj_resp.json()["adjustment_delta_vnd"] == "500000"

    # 3. Verify updated balance
    wallet2 = client.get("/v1/wallets/cash", headers=headers).json()
    assert wallet2["balance_vnd"] == "500000"
