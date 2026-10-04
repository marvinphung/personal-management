from fastapi import APIRouter, Depends
from pydantic import BaseModel
from qlt.config import get_settings
from qlt.db import get_connection
from qlt.ingest.registry import get_active_collector
from qlt.ingest.service import CollectorEventItem, process_collector_events

router = APIRouter(prefix="/v1/collector", tags=["Collector Ingest"])


class HeartbeatRequest(BaseModel):
    queue_size: int = 0
    listener_connected: bool = True
    counters: dict[str, int] = {}


@router.get("/registry")
def get_collector_registry(active_collector: dict = Depends(get_active_collector)):
    settings = get_settings()
    schema = settings.database_schema

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT b.id as binding_id, b.bank_code, b.account_number, b.version as binding_version,
                       u.capture_epoch
                FROM {schema}.bank_bindings b
                JOIN {schema}.users u ON b.user_id = u.id
                WHERE u.status = 'active' AND u.capture_enabled = true;
                """
            )
            rows = cur.fetchall()

    return {
        "collector_epoch": active_collector["epoch"],
        "bindings": [
            {
                "binding_id": str(r["binding_id"]),
                "bank_code": r["bank_code"],
                "account_number": r["account_number"],
                "binding_version": r["binding_version"],
                "capture_epoch": r["capture_epoch"],
            }
            for r in rows
        ],
    }


from qlt.messaging.ingestion import CollectorEventItem, process_collector_events_async


@router.post("/events")
async def ingest_events(
    events: list[CollectorEventItem],
    active_collector: dict = Depends(get_active_collector),
):
    results = await process_collector_events_async(events, active_collector)
    return results


@router.post("/heartbeat")
def collector_heartbeat(
    req: HeartbeatRequest,
    active_collector: dict = Depends(get_active_collector),
):
    settings = get_settings()
    schema = settings.database_schema

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {schema}.collector_devices
                SET last_heartbeat_at = NOW()
                WHERE id = %s;
                """,
                (str(active_collector["id"]),),
            )
        conn.commit()

    return {"status": "ok"}
