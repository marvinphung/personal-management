import asyncio

_backend_loop: asyncio.AbstractEventLoop | None = None


def bind_backend_loop(loop: asyncio.AbstractEventLoop | None):
    global _backend_loop
    _backend_loop = loop


def run_backend_coroutine(coro):
    """Sync HTTP workers must use the lifespan loop that owns NATS and DB pools."""
    if _backend_loop is not None and _backend_loop.is_running():
        try:
            current = asyncio.get_running_loop()
        except RuntimeError:
            current = None
        if current is _backend_loop:
            coro.close()
            raise RuntimeError("Call the async service directly on the backend event loop")
        future = asyncio.run_coroutine_threadsafe(coro, _backend_loop)
        try:
            return future.result(timeout=30)
        except TimeoutError:
            future.cancel()
            raise

    async def isolated():
        from qlt.db import close_async_pool
        from qlt.messaging.client import close_nats
        try:
            return await coro
        finally:
            await close_nats()
            await close_async_pool()
    return asyncio.run(isolated())
