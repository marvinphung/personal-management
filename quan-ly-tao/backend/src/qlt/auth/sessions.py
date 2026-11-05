from datetime import datetime, timedelta, timezone
import hashlib
import secrets
import uuid
import psycopg
from qlt.config import get_settings
from qlt.db import get_connection


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_token() -> str:
    # 256-bit random token
    return secrets.token_urlsafe(32)


def create_session(user_id: uuid.UUID, scope: str = "user") -> tuple[str, datetime]:
    settings = get_settings()
    token = generate_token()
    token_hash = hash_token(token)
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.session_lifetime_days)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.sessions (
                    token_hash, user_id, expires_at, scope
                ) VALUES (%s, %s, %s, %s);
                """,
                (token_hash, str(user_id), expires_at, scope),
            )
        conn.commit()
    return token, expires_at


def verify_session(token: str) -> dict | None:
    settings = get_settings()
    token_hash = hash_token(token)
    now = datetime.now(timezone.utc)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT s.user_id, s.scope, u.username, u.role, u.status, u.capture_enabled,
                       u.must_change_password, u.deleted_at
                FROM {settings.database_schema}.sessions s
                JOIN {settings.database_schema}.users u ON s.user_id = u.id
                WHERE s.token_hash = %s
                  AND s.revoked_at IS NULL
                  AND s.expires_at > %s;
                """,
                (token_hash, now),
            )
            row = cur.fetchone()
            if not row:
                return None
            return dict(row)


def revoke_session(token: str) -> None:
    settings = get_settings()
    token_hash = hash_token(token)
    now = datetime.now(timezone.utc)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.sessions
                SET revoked_at = %s
                WHERE token_hash = %s;
                """,
                (now, token_hash),
            )
        conn.commit()


def create_widget_token(user_id: uuid.UUID) -> tuple[str, datetime]:
    settings = get_settings()
    token = generate_token()
    token_hash = hash_token(token)
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.widget_token_lifetime_days)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.widget_tokens (
                    token_hash, user_id, expires_at
                ) VALUES (%s, %s, %s);
                """,
                (token_hash, str(user_id), expires_at),
            )
        conn.commit()
    return token, expires_at


def verify_widget_token(token: str) -> dict | None:
    settings = get_settings()
    token_hash = hash_token(token)
    now = datetime.now(timezone.utc)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT wt.user_id, u.username, u.role, u.status, u.capture_enabled,
                       u.must_change_password, u.deleted_at
                FROM {settings.database_schema}.widget_tokens wt
                JOIN {settings.database_schema}.users u ON wt.user_id = u.id
                WHERE wt.token_hash = %s
                  AND wt.revoked_at IS NULL
                  AND wt.expires_at > %s;
                """,
                (token_hash, now),
            )
            row = cur.fetchone()
            if not row:
                return None
            return dict(row)


def revoke_widget_token(token: str) -> None:
    settings = get_settings()
    token_hash = hash_token(token)
    now = datetime.now(timezone.utc)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.widget_tokens
                SET revoked_at = %s
                WHERE token_hash = %s;
                """,
                (now, token_hash),
            )
        conn.commit()


def revoke_all_user_sessions(user_id: uuid.UUID) -> None:
    settings = get_settings()
    now = datetime.now(timezone.utc)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.sessions
                SET revoked_at = %s
                WHERE user_id = %s AND revoked_at IS NULL;
                """,
                (now, str(user_id)),
            )
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.widget_tokens
                SET revoked_at = %s
                WHERE user_id = %s AND revoked_at IS NULL;
                """,
                (now, str(user_id)),
            )
        conn.commit()

