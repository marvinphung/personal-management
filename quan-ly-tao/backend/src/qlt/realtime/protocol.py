import json
import uuid
from typing import Any

PROTOCOL_VERSION = "1.0"


def make_frame(
    msg_type: str,
    connection_id: str,
    inbox_revision: int,
    data: dict[str, Any],
) -> dict[str, Any]:
    """Constructs a standardized v1 Realtime Gateway envelope."""
    return {
        "protocol_version": PROTOCOL_VERSION,
        "type": msg_type,
        "connection_id": connection_id,
        "inbox_revision": inbox_revision,
        "data": data,
    }


def chunk_snapshot(
    connection_id: str,
    inbox_revision: int,
    events: list[dict[str, Any]],
    chunk_threshold_bytes: int = 256 * 1024,
) -> list[dict[str, Any]]:
    """Splits an inbox snapshot into chunk frames followed by a complete frame

    if the serialized payload exceeds the chunk threshold.
    """
    full_data = {
        "pending_count": len(events),
        "events": events,
    }
    full_frame = make_frame("inbox.snapshot", connection_id, inbox_revision, full_data)
    encoded = json.dumps(full_frame).encode("utf-8")

    # If within threshold, send single unchunked frame
    if len(encoded) <= chunk_threshold_bytes or not events:
        return [full_frame]

    # Split into chunks
    snapshot_id = str(uuid.uuid4())
    frames: list[dict[str, Any]] = []

    # Calculate events per chunk estimate
    avg_event_bytes = max(1, len(encoded) // len(events))
    target_chunk_size = max(1, (chunk_threshold_bytes // 2) // avg_event_bytes)

    chunks = [events[i : i + target_chunk_size] for i in range(0, len(events), target_chunk_size)]
    total_chunks = len(chunks)

    for idx, chunk in enumerate(chunks):
        chunk_frame = make_frame(
            msg_type="inbox.snapshot_chunk",
            connection_id=connection_id,
            inbox_revision=inbox_revision,
            data={
                "snapshot_id": snapshot_id,
                "chunk_index": idx,
                "total_chunks": total_chunks,
                "events": chunk,
            },
        )
        frames.append(chunk_frame)

    # Completion frame
    complete_frame = make_frame(
        msg_type="inbox.snapshot_complete",
        connection_id=connection_id,
        inbox_revision=inbox_revision,
        data={
            "snapshot_id": snapshot_id,
            "total_chunks": total_chunks,
            "total_events": len(events),
            "pending_count": len(events),
        },
    )
    frames.append(complete_frame)

    return frames
