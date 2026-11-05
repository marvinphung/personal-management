import psycopg

from qlt.bootstrap_admin import bootstrap_admin
from qlt.config import get_settings


def test_bootstrap_admin_creates_and_updates_case_insensitive_username():
    settings = get_settings()
    username = "bootstrap_test_admin"

    bootstrap_admin(username.upper(), "FirstPassword#2026")
    bootstrap_admin(username, "SecondPassword#2026")

    with psycopg.connect(settings.database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT COUNT(*), MIN(role), MIN(status)
                FROM {settings.database_schema}.users
                WHERE LOWER(username) = %s
                """,
                (username,),
            )
            count, role, status = cur.fetchone()

    assert count == 1
    assert role == "admin"
    assert status == "active"
