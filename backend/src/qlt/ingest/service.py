from datetime import datetime
import uuid
from pydantic import BaseModel
import psycopg
from qlt.config import get_settings
from qlt.db import get_connection
from qlt.ingest.fingerprint import compute_event_fingerprint


class CollectorEventItem(BaseModel):
    event_id: str
    collector_epoch: int
    binding_id: str
    binding_version: int
    capture_epoch: int
    bank_code: str
    owner_account: str
    direction: str
    amount_vnd: str
    occurred_at: str
    time_source: str
    bank_description: str
    bank_reference: str | None = None
    source_package: str
    parser_version: str
    source_event_key: str


def process_collector_events(
    events: list[CollectorEventItem], active_collector: dict
) -> list[dict]:
    settings = get_settings()
    schema = settings.database_schema
    collector_epoch = active_collector["epoch"]
    results = []

    with get_connection() as conn:
        with conn.cursor() as cur:
            for ev in events:
                # 1. Collector epoch validation (fencing check)
                if ev.collector_epoch != collector_epoch:
                    results.append({"event_id": ev.event_id, "status": "dropped", "reason": "STALE_COLLECTOR_EPOCH"})
                    continue

                # 2. Look up binding and associated user
                cur.execute(
                    f"""
                    SELECT b.id, b.user_id, b.version, b.capture_from,
                           u.status as user_status, u.capture_enabled, u.capture_epoch
                    FROM {schema}.bank_bindings b
                    JOIN {schema}.users u ON b.user_id = u.id
                    WHERE b.id = %s AND b.bank_code = %s AND b.account_number = %s;
                    """,
                    (ev.binding_id, ev.bank_code, ev.owner_account),
                )
                binding = cur.fetchone()
                if not binding:
                    results.append({"event_id": ev.event_id, "status": "dropped", "reason": "BINDING_NOT_FOUND"})
                    continue

                user_id = binding["user_id"]

                # 3. User status and capture validation
                if binding["user_status"] != "active" or not binding["capture_enabled"]:
                    results.append({"event_id": ev.event_id, "status": "dropped", "reason": "USER_CAPTURE_DISABLED"})
                    continue

                # 4. Capture epoch & binding version check
                if ev.capture_epoch != binding["capture_epoch"] or ev.binding_version != binding["version"]:
                    results.append({"event_id": ev.event_id, "status": "dropped", "reason": "STALE_CAPTURE_EPOCH"})
                    continue

                # 5. Parse occurred_at and amount
                try:
                    amount = int(ev.amount_vnd)
                    occurred_dt = datetime.fromisoformat(ev.occurred_at.replace("Z", "+00:00"))
                except Exception:
                    results.append({"event_id": ev.event_id, "status": "dropped", "reason": "INVALID_FORMAT"})
                    continue

                # 6. Compute HMAC-SHA256 fingerprint
                fingerprint = compute_event_fingerprint(
                    bank_code=ev.bank_code,
                    owner_account=ev.owner_account,
                    direction=ev.direction,
                    amount_vnd=amount,
                    occurred_at_iso=ev.occurred_at,
                    bank_description=ev.bank_description,
                    bank_reference=ev.bank_reference,
                    source_event_key=ev.source_event_key,
                )

                # 7. Check if already ingested
                cur.execute(
                    f"SELECT fingerprint FROM {schema}.ingest_receipts WHERE fingerprint = %s;",
                    (fingerprint,),
                )
                if cur.fetchone():
                    # Terminal duplicate ACK
                    results.append({"event_id": ev.event_id, "status": "duplicate"})
                    continue

                # 8. Atomic insert of ingest_receipt and pending_bank_event
                pending_id = uuid.uuid4()
                try:
                    cur.execute(
                        f"INSERT INTO {schema}.ingest_receipts (fingerprint) VALUES (%s);",
                        (fingerprint,),
                    )
                    cur.execute(
                        f"""
                        INSERT INTO {schema}.pending_bank_events (
                            id, user_id, binding_id, bank_code, owner_account_snapshot,
                            amount_vnd, direction, occurred_at, time_source, bank_description,
                            fingerprint, parser_version
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
                        """,
                        (
                            str(pending_id),
                            str(user_id),
                            ev.binding_id,
                            ev.bank_code,
                            ev.owner_account,
                            amount,
                            ev.direction,
                            occurred_dt,
                            ev.time_source,
                            ev.bank_description,
                            fingerprint,
                            ev.parser_version,
                        ),
                    )
                    # Update binding first_received_at if null
                    cur.execute(
                        f"""
                        UPDATE {schema}.bank_bindings
                        SET first_received_at = NOW()
                        WHERE id = %s AND first_received_at IS NULL;
                        """,
                        (ev.binding_id,),
                    )
                    # Increment user revision
                    cur.execute(
                        f"""
                        INSERT INTO {schema}.user_revisions (user_id, revision)
                        VALUES (%s, 1)
                        ON CONFLICT (user_id) DO UPDATE SET revision = {schema}.user_revisions.revision + 1;
                        """,
                        (str(user_id),),
                    )
                    results.append({"event_id": ev.event_id, "status": "accepted"})
                except psycopg.errors.UniqueViolation:
                    # Fingerprint race
                    results.append({"event_id": ev.event_id, "status": "duplicate"})

        conn.commit()

    return results
