import asyncio
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status

from qlt.auth.sessions import verify_session
from qlt.config import get_settings
from qlt.messaging.inbox import get_user_inbox_events
from qlt.realtime.hub import hub
from qlt.realtime.protocol import chunk_snapshot, make_frame

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Realtime Gateway"])


@router.websocket("/v1/realtime")
async def websocket_realtime_endpoint(websocket: WebSocket):
    # 1. Authenticate via standard Authorization header
    auth_header = websocket.headers.get("authorization") or websocket.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Unauthorized: Missing Bearer token")
        return

    token = auth_header[len("Bearer ") :].strip()
    user = verify_session(token)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Unauthorized: Invalid session")
        return

    if user.get("deleted_at") is not None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Account deleted")
        return

    if user.get("status") != "active" or user.get("must_change_password"):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="User not active")
        return

    user_id = user["user_id"]
    connection_id = str(uuid.uuid4())
    settings = get_settings()

    await websocket.accept()
    await hub.register(user_id, connection_id, websocket, token)

    try:
        async with hub.send_lock(user_id):
            # 2. Fetch initial inbox state and revision
            inbox_rev, events = await get_user_inbox_events(user_id)

            # 3. Send 'hello' frame
            hello_frame = make_frame(
                msg_type="hello",
                connection_id=connection_id,
                inbox_revision=inbox_rev,
                data={
                    "user_id": str(user_id),
                    "server_time": datetime.now(timezone.utc).isoformat(),
                    "heartbeat_interval_seconds": 30,
                    "max_frame_bytes": settings.realtime_chunk_threshold_bytes,
                },
            )
            await websocket.send_json(hello_frame)

            # 4. Send initial authoritative inbox snapshot
            initial_frames = chunk_snapshot(
                connection_id=connection_id,
                inbox_revision=inbox_rev,
                events=events,
                chunk_threshold_bytes=settings.realtime_chunk_threshold_bytes,
            )
            for frame in initial_frames:
                await websocket.send_json(frame)

        # 5. Bidirectional loop (heartbeats and client messages)
        while True:
            msg = await asyncio.wait_for(websocket.receive_json(), timeout=60)
            session = await asyncio.to_thread(verify_session, token)
            if not session or session["status"] != "active" or session["must_change_password"]:
                await websocket.close(code=1008, reason="Session revoked")
                break
            msg_type = msg.get("type")

            if msg_type == "ping":
                client_ts = (msg.get("data") or {}).get("timestamp", 0)
                pong_frame = make_frame(
                    msg_type="pong",
                    connection_id=connection_id,
                    inbox_revision=inbox_rev,
                    data={
                        "client_timestamp": client_ts,
                        "server_timestamp": int(datetime.now(timezone.utc).timestamp() * 1000),
                    },
                )
                async with hub.send_lock(user_id):
                    await websocket.send_json(pong_frame)

    except (WebSocketDisconnect, asyncio.CancelledError):
        logger.info(f"WebSocket client [{connection_id}] disconnected")
    except Exception as e:
        logger.warning(f"WebSocket connection [{connection_id}] terminated: {e}")
    finally:
        await hub.unregister(user_id, connection_id)
