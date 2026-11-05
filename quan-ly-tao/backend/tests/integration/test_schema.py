import uuid
import psycopg
import pytest
from qlt.config import get_settings


@pytest.fixture
def db_conn():
    settings = get_settings()
    settings.assert_test_database()
    conn = psycopg.connect(settings.database_url, autocommit=False)
    yield conn
    conn.rollback()
    conn.close()


def test_leading_zero_account_preserved(db_conn):
    user_id = uuid.uuid4()
    acc_num = f"00{uuid.uuid4().int % 10000000000:010d}"
    with db_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO qlt.users (id, username, password_hash, status) VALUES (%s, %s, 'hash', 'active');",
            (str(user_id), f"user_{user_id.hex[:8]}"),
        )
        cur.execute(
            "INSERT INTO qlt.bank_bindings (user_id, bank_code, account_number) VALUES (%s, 'bidv', %s) RETURNING account_number;",
            (str(user_id), acc_num),
        )
        row = cur.fetchone()
        assert row is not None
        assert row[0] == acc_num


def test_unique_bank_account_per_bank(db_conn):
    user_a = uuid.uuid4()
    user_b = uuid.uuid4()
    acc_num = f"{uuid.uuid4().int % 10000000000:010d}"
    with db_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO qlt.users (id, username, password_hash, status) VALUES (%s, %s, 'hash', 'active'), (%s, %s, 'hash', 'active');",
            (str(user_a), f"user_{user_a.hex[:8]}", str(user_b), f"user_{user_b.hex[:8]}"),
        )
        cur.execute(
            "INSERT INTO qlt.bank_bindings (user_id, bank_code, account_number) VALUES (%s, 'bidv', %s);",
            (str(user_a), acc_num),
        )
        # Another user trying to bind the same bank + account must fail with unique constraint violation
        with pytest.raises(psycopg.errors.UniqueViolation):
            with db_conn.transaction():
                cur.execute(
                    "INSERT INTO qlt.bank_bindings (user_id, bank_code, account_number) VALUES (%s, 'bidv', %s);",
                    (str(user_b), acc_num),
                )


def test_one_active_collector_constraint(db_conn):
    with db_conn.cursor() as cur:
        cur.execute("DELETE FROM qlt.collector_devices;")
        # First active collector
        cur.execute(
            "INSERT INTO qlt.collector_devices (credential_hash, state, epoch) VALUES ('hash_1', 'active', 1);"
        )
        # Attempting second active collector must violate one_active_collector index
        with pytest.raises(psycopg.errors.UniqueViolation):
            with db_conn.transaction():
                cur.execute(
                    "INSERT INTO qlt.collector_devices (credential_hash, state, epoch) VALUES ('hash_2', 'active', 2);"
                )


def test_money_limit_constraint(db_conn):
    user_id = uuid.uuid4()
    cat_id = uuid.uuid4()
    with db_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO qlt.users (id, username, password_hash, status) VALUES (%s, %s, 'hash', 'active');",
            (str(user_id), f"user_{user_id.hex[:8]}"),
        )
        cur.execute(
            "INSERT INTO qlt.categories (id, user_id, direction, name, name_key) VALUES (%s, %s, 'expense', 'Ăn uống', 'an_uong');",
            (str(cat_id), str(user_id)),
        )
        # Valid amount
        cur.execute(
            """
            INSERT INTO qlt.transactions (user_id, direction, amount_vnd, occurred_at, source, category_id)
            VALUES (%s, 'expense', 50000, NOW(), 'manual', %s);
            """,
            (str(user_id), str(cat_id)),
        )
        # Zero or negative must fail
        with pytest.raises(psycopg.errors.CheckViolation):
            with db_conn.transaction():
                cur.execute(
                    """
                    INSERT INTO qlt.transactions (user_id, direction, amount_vnd, occurred_at, source, category_id)
                    VALUES (%s, 'expense', 0, NOW(), 'manual', %s);
                    """,
                    (str(user_id), str(cat_id)),
                )
        # Exceeding maximum must fail
        with pytest.raises(psycopg.errors.CheckViolation):
            with db_conn.transaction():
                cur.execute(
                    """
                    INSERT INTO qlt.transactions (user_id, direction, amount_vnd, occurred_at, source, category_id)
                    VALUES (%s, 'expense', 9000000000000001, NOW(), 'manual', %s);
                    """,
                    (str(user_id), str(cat_id)),
                )
