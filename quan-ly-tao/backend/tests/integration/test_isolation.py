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


def test_tenant_rls_isolation(db_conn):
    user_a = uuid.uuid4()
    user_b = uuid.uuid4()
    cat_a = uuid.uuid4()
    cat_b = uuid.uuid4()

    with db_conn.cursor() as cur:
        # Create users
        cur.execute(
            "INSERT INTO qlt.users (id, username, password_hash, status) VALUES (%s, %s, 'h', 'active'), (%s, %s, 'h', 'active');",
            (str(user_a), f"a_{user_a.hex[:6]}", str(user_b), f"b_{user_b.hex[:6]}"),
        )
        # Insert categories without RLS restriction (table owner / test role)
        cur.execute(
            """
            INSERT INTO qlt.categories (id, user_id, direction, name, name_key) VALUES
            (%s, %s, 'expense', 'A Cat', 'a_cat'),
            (%s, %s, 'expense', 'B Cat', 'b_cat');
            """,
            (str(cat_a), str(user_a), str(cat_b), str(user_b)),
        )

        # Set tenant context to user_a under non-superuser qlt_app role
        cur.execute("SET ROLE qlt_app;")
        cur.execute("SELECT set_config('app.user_id', %s, true);", (str(user_a),))
        cur.execute("SELECT id FROM qlt.categories WHERE user_id = %s;", (str(user_a),))
        assert len(cur.fetchall()) == 1

        # Attempting to query user_b's category under user_a's RLS policy should yield 0 rows
        cur.execute("SELECT id FROM qlt.categories WHERE id = %s;", (str(cat_b),))
        assert cur.fetchall() == []

        # Reset tenant context for user_b
        cur.execute("SELECT set_config('app.user_id', %s, true);", (str(user_b),))
        cur.execute("SELECT id FROM qlt.categories WHERE id = %s;", (str(cat_b),))
        assert len(cur.fetchall()) == 1
        cur.execute("SELECT id FROM qlt.categories WHERE id = %s;", (str(cat_a),))
        assert cur.fetchall() == []
        cur.execute("RESET ROLE;")
