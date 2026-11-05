from contextlib import asynccontextmanager, contextmanager
from typing import AsyncGenerator, Generator
import uuid
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool, ConnectionPool
from qlt.config import get_settings

_pool: ConnectionPool | None = None
_async_pool: AsyncConnectionPool | None = None


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
        open=True,
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


async def init_async_pool(min_size: int = 2, max_size: int = 10) -> AsyncConnectionPool:
    global _async_pool
    if _async_pool is not None:
        return _async_pool
    settings = get_settings()
    _async_pool = AsyncConnectionPool(
        conninfo=settings.database_url,
        min_size=min_size,
        max_size=max_size,
        timeout=10.0,
        kwargs={"autocommit": False, "row_factory": dict_row},
        open=False,
    )
    await _async_pool.open()
    return _async_pool


async def get_async_pool() -> AsyncConnectionPool:
    global _async_pool
    if _async_pool is None:
        return await init_async_pool()
    return _async_pool


async def close_async_pool() -> None:
    global _async_pool
    if _async_pool is not None:
        await _async_pool.close()
        _async_pool = None


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


@asynccontextmanager
async def get_async_connection() -> AsyncGenerator[psycopg.AsyncConnection, None]:
    pool = await get_async_pool()
    async with pool.connection() as conn:
        yield conn


@asynccontextmanager
async def get_async_tenant_connection(
    user_id: uuid.UUID,
) -> AsyncGenerator[psycopg.AsyncConnection, None]:
    """Provide an async transaction-bound connection with app.user_id set for RLS policies."""
    pool = await get_async_pool()
    async with pool.connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                await cur.execute(
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


async def check_async_db_ready() -> bool:
    try:
        async with get_async_connection() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT 1;")
                row = await cur.fetchone()
                return row is not None
    except Exception:
        return False
