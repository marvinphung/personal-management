import asyncio
import logging
from datetime import datetime, timedelta, timezone

from nats.js.errors import NotFoundError

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.client import get_jetstream
from qlt.messaging.ingestion import lock_revision, pending_notifications
from qlt.messaging.integrity import verified_payload
from qlt.messaging.receipts import lock_receipt_by_id
from qlt.messaging.stream import build_event_subject, ensure_stream

logger = logging.getLogger(__name__)


async def recover_stuck_publishing_receipts(max_age_seconds: int = 60) -> int:
    settings = get_settings()
    schema = settings.database_schema
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=max_age_seconds)
    async with get_async_connection() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                f"""SELECT id,user_id,binding_id FROM {schema}.bank_event_receipts
                WHERE state='publishing' AND created_at<=%s ORDER BY created_at LIMIT 50""",
                (cutoff,),
            )
            stuck = await cur.fetchall()
    js = await get_jetstream()
    recovered = 0
    for candidate in stuck:
        try:
            async with get_async_connection() as conn:
                async with conn.transaction():
                    async with conn.cursor() as cur:
                        await cur.execute(
                            f"SELECT status,capture_enabled,capture_epoch FROM {schema}.users WHERE id=%s FOR SHARE",
                            (candidate["user_id"],),
                        )
                        user = await cur.fetchone()
                        if not user or user["status"] != "active" or not user["capture_enabled"]:
                            continue
                        await cur.execute(
                            f"SELECT id,version FROM {schema}.bank_bindings WHERE id=%s FOR SHARE",
                            (candidate["binding_id"],),
                        )
                        binding = await cur.fetchone()
                        if not binding:
                            continue
                        await lock_revision(cur, schema, candidate["user_id"])
                        receipt = await lock_receipt_by_id(cur, schema, candidate["id"])
                        # Candidate discovery is not a lease: recheck under the lock.
                        if not receipt or receipt["state"] != "publishing":
                            continue
                        if receipt["capture_epoch"] is None or receipt["binding_version"] is None:
                            continue
                        if (receipt["capture_epoch"] != user["capture_epoch"]
                                or receipt["binding_version"] != binding["version"]):
                            # Keep the HMAC tombstone, remove only this obsolete payload.
                            from qlt.messaging.outbox import enqueue_outbox_job
                            from qlt.messaging.schemas import OutboxJobKind
                            await cur.execute(f"UPDATE {schema}.bank_event_receipts SET state='purged' WHERE id=%s", (receipt["id"],))
                            await enqueue_outbox_job(cur, schema, OutboxJobKind.PAYLOAD_CLEANUP,
                                receipt["user_id"], receipt["id"], settings.get_stream_name(), receipt["stream_seq"])
                            continue
                        msg = await js.get_msg(settings.get_stream_name(),
                            subject=build_event_subject(receipt["user_id"], receipt["id"]))
                        verified_payload(msg, receipt)
                        if await pending_notifications(cur, schema, receipt, settings.get_stream_name(), msg.seq):
                            recovered += 1
        except NotFoundError:
            continue  # Collector still owns the missing payload and will retry.
        except Exception:
            logger.exception("Publishing recovery deferred for %s", candidate["id"])
    return recovered


async def run_reconciliation_coordinator(stop_event: asyncio.Event, interval_seconds: int = 30):
    from qlt.realtime.hub import hub
    while not stop_event.is_set():
        try:
            await ensure_stream(await get_jetstream())
            await recover_stuck_publishing_receipts()
            # Rebuild authoritative snapshots for active sockets even if an outbox
            # notification was missed or another backend process consumed it.
            await hub.reconcile_active_connections()
        except asyncio.CancelledError:
            break
        except Exception:
            logger.exception("Reconciliation deferred")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=interval_seconds)
        except asyncio.TimeoutError:
            pass
