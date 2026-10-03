from contextlib import contextmanager
from typing import Generator
import uuid
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool
from qlt.config import get_settings

_pool: ConnectionPool | None = None


def init_pool(min_size: int = 2, max_size: int = 5) -> ConnectionPool:
    global _pool
    if _pool is not None:
        return _pool
    settings = get_settings()
    _pool = ConnectionPool(
        conninfo=settings.database_url,
        min_size=min_size,
        max_size=max_size,
        timeout=10.0,
        kwargs={"autocommit": False, "row_factory": dict_row},
    )
    return _pool


def get_pool() -> ConnectionPool:
    global _pool
    if _pool is None:
        return init_pool()
    return _pool


def close_pool() -> None:
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


@contextmanager
def get_connection() -> Generator[psycopg.Connection, None, None]:
    pool = get_pool()
    with pool.connection() as conn:
        yield conn


@contextmanager
def get_tenant_connection(user_id: uuid.UUID) -> Generator[psycopg.Connection, None, None]:
    """Provide a transaction-bound connection with app.user_id set for RLS policies."""
    pool = get_pool()
    with pool.connection() as conn:
        with conn.transaction():
            # Set transaction-local setting for RLS
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT set_config('app.user_id', %s, true);",
                    (str(user_id),),
                )
            yield conn


def check_db_ready() -> bool:
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
                row = cur.fetchone()
                return row is not None
    except Exception:
        return False
