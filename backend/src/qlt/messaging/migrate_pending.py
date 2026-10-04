import argparse
import asyncio
import logging
import sys
from decimal import Decimal

from nats.js.errors import NotFoundError

from qlt.config import get_settings
from qlt.db import get_async_connection
from qlt.messaging.client import close_nats, get_jetstream
from qlt.messaging.ingestion import lock_revision, pending_notifications
from qlt.messaging.integrity import verified_payload
from qlt.messaging.receipts import (
    compute_payload_hash,
    find_receipt_by_fingerprint,
    lock_receipt_by_id,
    reserve_receipt,
)
from qlt.messaging.schemas import BankEventPayload, ReceiptState
from qlt.messaging.stream import build_event_msg_id, build_event_subject, ensure_stream

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("qlt.migrate_pending")


async def migrate_pending_events(
    schema: str = "qlt",
    dry_run: bool = False,
    batch_size: int = 50,
) -> dict[str, int]:
    """Migrates existing rows from qlt.pending_bank_events to NATS JetStream

    and populates qlt.bank_event_receipts metadata.
    """
    settings = get_settings()
    if schema != settings.database_schema:
        raise ValueError("Migration schema must match DATABASE_SCHEMA")
    logger.info(f"Starting pending bank events migration (schema: {schema}, dry_run: {dry_run})")

    # Connect to NATS
    js = await get_jetstream()
    if not dry_run:
        await ensure_stream(js)
    else:
        await js.stream_info(settings.get_stream_name())

    stats = {
        "found": 0,
        "migrated": 0,
        "already_present": 0,
        "errors": 0,
    }

    async with get_async_connection() as conn:
        async with conn.transaction():
            async with conn.cursor() as cur:
                # Check if old table exists
                await cur.execute(
                    """
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables
                        WHERE table_schema = %s AND table_name = 'pending_bank_events'
                    ) AS tbl_exists;
                    """,
                    (schema,),
                )
                row = await cur.fetchone()
                exists = bool(row["tbl_exists"]) if row else False
                if not exists:
                    logger.info("Table 'pending_bank_events' does not exist; nothing to migrate.")
                    await close_nats()
                    return stats

                await cur.execute(
                    f"""
                    SELECT id, user_id, binding_id, bank_code, owner_account_snapshot,
                           amount_vnd, direction, occurred_at, time_source, received_at,
                           bank_description, fingerprint, parser_version
                    FROM {schema}.pending_bank_events
                    ORDER BY occurred_at ASC;
                    """
                )
                rows = await cur.fetchall()
                stats["found"] = len(rows)

    logger.info(f"Found {stats['found']} existing pending bank event rows to migrate.")

    if dry_run or not rows:
        await close_nats()
        return stats

    for row in rows:
        event_id = row["id"]
        user_id = row["user_id"]
        fingerprint = row["fingerprint"]

        try:
            async with get_async_connection() as conn:
                async with conn.transaction():
                    async with conn.cursor() as cur:
                        await cur.execute(f"SELECT status,capture_epoch FROM {schema}.users WHERE id=%s FOR SHARE", (user_id,))
                        user = await cur.fetchone()
                        if not user or user["status"] != "active":
                            stats["already_present"] += 1
                            continue
                        await lock_revision(cur, schema, user_id)
                        existing = await find_receipt_by_fingerprint(cur, schema, fingerprint)
                        if existing and existing["state"] != ReceiptState.PUBLISHING.value:
                            stats["already_present"] += 1
                            continue

                        # Build BankEventPayload
                        payload = BankEventPayload(
                            id=event_id,
                            user_id=user_id,
                            binding_id=row["binding_id"],
                            source_type=row["bank_code"],
                            account_number_mask=row["owner_account_snapshot"],
                            amount=Decimal(row["amount_vnd"]),
                            direction=row["direction"],
                            booking_time=row["occurred_at"],
                            raw_description=row["bank_description"],
                            raw_payload={
                                "parser_version": row["parser_version"],
                                "time_source": row["time_source"],
                            },
                            created_at=row["received_at"],
                        )
                        payload_hash = compute_payload_hash(payload.model_dump())

                        if not existing:
                            await cur.execute(f"SELECT version FROM {schema}.bank_bindings WHERE id=%s", (row["binding_id"],))
                            binding = await cur.fetchone()
                            await reserve_receipt(
                                cur=cur,
                                schema=schema,
                                event_id=event_id,
                                user_id=user_id,
                                binding_id=row["binding_id"],
                                fingerprint=fingerprint,
                                payload_hash=payload_hash,
                                capture_epoch=user["capture_epoch"],
                                binding_version=binding["version"] if binding else None,
                            )

            # Repeat fencing after reservation; keep it across bounded publication.
            async with get_async_connection() as conn:
                async with conn.transaction():
                    async with conn.cursor() as cur:
                        await cur.execute(f"SELECT status FROM {schema}.users WHERE id=%s FOR SHARE", (user_id,))
                        user = await cur.fetchone()
                        if not user or user["status"] != "active":
                            stats["already_present"] += 1
                            continue
                        await lock_revision(cur, schema, user_id)
                        receipt = await lock_receipt_by_id(cur, schema, event_id)
                        if not receipt or receipt["state"] != "publishing":
                            stats["already_present"] += 1
                            continue
                        subject = build_event_subject(user_id, event_id)
                        try:
                            msg = await js.get_msg(settings.get_stream_name(), subject=subject)
                            verified_payload(msg, receipt)
                            seq = msg.seq
                        except NotFoundError:
                            if payload_hash != receipt["payload_hash"]:
                                raise ValueError("Migration payload differs from reservation")
                            ack = await js.publish(subject, payload.model_dump_json().encode(),
                                headers={"Nats-Msg-Id": build_event_msg_id(event_id)})
                            if ack.stream != settings.get_stream_name():
                                raise ValueError("Unexpected migration stream")
                            seq = ack.seq
                        await pending_notifications(cur, schema, receipt, settings.get_stream_name(), seq)
            stats["migrated"] += 1
            logger.info("Migrated event %s -> seq %s", event_id, seq)

        except Exception as e:
            stats["errors"] += 1
            logger.error(f"Failed to migrate event {event_id}: {e}")

    await close_nats()
    logger.info(f"Migration completed: {stats}")
    return stats


def main():
    parser = argparse.ArgumentParser(description="Migrate pending bank events to NATS JetStream")
    parser.add_argument("--schema", default="qlt", help="Target database schema (default: qlt)")
    parser.add_argument("--dry-run", action="store_true", help="Inspect rows without publishing or modifying DB")
    parser.add_argument("--batch-size", type=int, default=50, help="Batch size for migration")
    args = parser.parse_args()

    try:
        asyncio.run(
            migrate_pending_events(
                schema=args.schema,
                dry_run=args.dry_run,
                batch_size=args.batch_size,
            )
        )
    except Exception as e:
        logger.error(f"Migration failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
