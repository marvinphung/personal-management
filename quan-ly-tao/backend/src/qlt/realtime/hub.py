import asyncio
import logging
import uuid

from fastapi import WebSocket

from qlt.auth.sessions import verify_session
from qlt.config import get_settings
from qlt.messaging.inbox import get_user_inbox_events
from qlt.messaging.worker import register_realtime_dispatcher
from qlt.realtime.protocol import chunk_snapshot, make_frame

logger = logging.getLogger(__name__)


class RealtimeHub:
    """Manages active WebSocket connections grouped by user_id and handles

    pushing authoritative inbox snapshots and sync invalidation frames.
    """

    def __init__(self):
        # user_id -> connection_id -> WebSocket
        self._connections: dict[uuid.UUID, dict[str, WebSocket]] = {}
        self._lock = asyncio.Lock()
        self._send_locks: dict[uuid.UUID, asyncio.Lock] = {}
        self._last_revisions: dict[str, int] = {}
        self._session_tokens: dict[str, str] = {}

    def send_lock(self, user_id: uuid.UUID) -> asyncio.Lock:
        return self._send_locks.setdefault(user_id, asyncio.Lock())

    async def register(self, user_id: uuid.UUID, connection_id: str, ws: WebSocket, token: str | None = None) -> None:
        async with self._lock:
            if user_id not in self._connections:
                self._connections[user_id] = {}
            self._connections[user_id][connection_id] = ws
            if token:
                self._session_tokens[connection_id] = token
            logger.info(f"Registered connection [{connection_id}] for user {user_id}")

    async def unregister(self, user_id: uuid.UUID, connection_id: str) -> None:
        async with self._lock:
            if user_id in self._connections:
                self._connections[user_id].pop(connection_id, None)
                self._last_revisions.pop(connection_id, None)
                self._session_tokens.pop(connection_id, None)
                if not self._connections[user_id]:
                    del self._connections[user_id]
            logger.info(f"Unregistered connection [{connection_id}] for user {user_id}")

    async def notify_user_inbox_invalidation(
        self,
        user_id: uuid.UUID,
        inbox_revision: int,
    ) -> None:
        """Called when an outbox invalidation job fires. Fetches latest inbox state

        and pushes authoritative snapshots to all connected sockets for this user.
        """
        async with self._lock:
            sockets = list(self._connections.get(user_id, {}).items())

        if not sockets:
            return

        settings = get_settings()
        # Serialize snapshot assembly AND all chunks, including initial delivery.
        # A failed assembly must propagate so the outbox retains its retry.
        async with self.send_lock(user_id):
            latest_inbox_rev, events = await get_user_inbox_events(user_id)
            for conn_id, ws in sockets:
                token = self._session_tokens.get(conn_id)
                session = await asyncio.to_thread(verify_session, token) if token else None
                if token and (not session or session["status"] != "active" or session["must_change_password"]):
                    await self.unregister(user_id, conn_id)
                    await ws.close(code=1008, reason="Session revoked")
                    continue
                if self._last_revisions.get(conn_id, -1) >= latest_inbox_rev:
                    continue
                try:
                    frames = chunk_snapshot(
                        connection_id=conn_id,
                        inbox_revision=latest_inbox_rev,
                        events=events,
                        chunk_threshold_bytes=settings.realtime_chunk_threshold_bytes,
                    )
                    for frame in frames:
                        await asyncio.wait_for(ws.send_json(frame), timeout=5.0)
                    self._last_revisions[conn_id] = latest_inbox_rev
                except Exception:
                    await self.unregister(user_id, conn_id)
                    try:
                        await ws.close(code=1011)
                    except Exception:
                        pass

    async def reconcile_active_connections(self):
        async with self._lock:
            users = list(self._connections)
        for user_id in users:
            try:
                await self.notify_user_inbox_invalidation(user_id, 0)
            except Exception:
                logger.warning("Active inbox reconciliation deferred for %s", user_id)

    async def broadcast_sync_required(
        self,
        user_id: uuid.UUID,
        entity_types: list[str],
        server_revision: int,
    ) -> None:
        """Pushes sync.required frame to notify client of catalog or ledger mutations."""
        async with self._lock:
            sockets = list(self._connections.get(user_id, {}).items())

        for conn_id, ws in sockets:
            frame = make_frame(
                msg_type="sync.required",
                connection_id=conn_id,
                inbox_revision=0,
                data={
                    "entity_types": entity_types,
                    "server_revision": server_revision,
                },
            )
            try:
                await asyncio.wait_for(ws.send_json(frame), timeout=3.0)
            except Exception as e:
                logger.warning(f"Error sending sync.required to connection [{conn_id}]: {e}")


# Singleton hub instance
hub = RealtimeHub()

# Wire into outbox worker dispatcher
register_realtime_dispatcher(hub.notify_user_inbox_invalidation)
