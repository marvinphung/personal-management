import uuid
from qlt.config import get_settings
from qlt.db import get_connection


def get_user_snapshot(user_id: uuid.UUID, known_revision: int | None = None) -> dict:
    """
    Fetches a consistent snapshot of all user-owned data under REPEATABLE READ isolation.
    Returns status: 'unchanged' if known_revision matches the current revision.
    """
    settings = get_settings()
    schema = settings.database_schema
    u_id = str(user_id)

    with get_connection() as conn:
        import psycopg
        conn.isolation_level = psycopg.IsolationLevel.REPEATABLE_READ
        with conn.cursor() as cur:
            # 1. Read current revision (initialize if missing)
            cur.execute(
                f"""
                INSERT INTO {schema}.user_revisions (user_id, revision)
                VALUES (%s, 1)
                ON CONFLICT (user_id) DO UPDATE SET revision = {schema}.user_revisions.revision
                RETURNING revision;
                """,
                (u_id,),
            )
            current_revision = cur.fetchone()["revision"]

            if known_revision is not None and known_revision == current_revision:
                return {
                    "status": "unchanged",
                    "revision": current_revision,
                }

            # 2. Categories
            cur.execute(
                f"""
                SELECT id, direction, name, name_key, icon, archived, seed_rank, version
                FROM {schema}.categories
                WHERE user_id = %s
                ORDER BY archived ASC, seed_rank ASC, name ASC;
                """,
                (u_id,),
            )
            categories = [
                {
                    "id": str(r["id"]),
                    "direction": r["direction"],
                    "name": r["name"],
                    "icon": r["icon"],
                    "archived": r["archived"],
                    "seed_rank": r["seed_rank"],
                    "version": r["version"],
                }
                for r in cur.fetchall()
            ]

            # 3. Tags
            cur.execute(
                f"""
                SELECT id, category_id, name, archived, version
                FROM {schema}.tags
                WHERE user_id = %s
                ORDER BY archived ASC, name ASC;
                """,
                (u_id,),
            )
            tags = [
                {
                    "id": str(r["id"]),
                    "category_id": str(r["category_id"]),
                    "name": r["name"],
                    "archived": r["archived"],
                    "version": r["version"],
                }
                for r in cur.fetchall()
            ]

            # 4. Transactions with tags
            cur.execute(
                f"""
                SELECT t.id, t.direction, t.amount_vnd, t.occurred_at, t.source,
                       t.bank_code_snapshot, t.owner_account_snapshot, t.bank_description,
                       t.category_id, t.user_note, t.purpose, t.version,
                       COALESCE(ARRAY_AGG(tt.tag_id) FILTER (WHERE tt.tag_id IS NOT NULL), '{{}}') as tag_ids
                FROM {schema}.transactions t
                LEFT JOIN {schema}.transaction_tags tt ON t.id = tt.transaction_id
                WHERE t.user_id = %s
                GROUP BY t.id
                ORDER BY t.occurred_at DESC, t.id DESC;
                """,
                (u_id,),
            )
            transactions = [
                {
                    "id": str(r["id"]),
                    "direction": r["direction"],
                    "amount_vnd": str(r["amount_vnd"]),
                    "occurred_at": r["occurred_at"].isoformat(),
                    "source": r["source"],
                    "bank_code_snapshot": r["bank_code_snapshot"],
                    "owner_account_snapshot": r["owner_account_snapshot"],
                    "bank_description": r["bank_description"],
                    "category_id": str(r["category_id"]),
                    "user_note": r["user_note"],
                    "purpose": r["purpose"],
                    "version": r["version"],
                    "tag_ids": [str(t) for t in r["tag_ids"]],
                }
                for r in cur.fetchall()
            ]

            # 5. Pending bank events
            cur.execute(
                f"""
                SELECT id, bank_code, owner_account_snapshot, amount_vnd, direction,
                       occurred_at, time_source, received_at, bank_description, version
                FROM {schema}.pending_bank_events
                WHERE user_id = %s
                ORDER BY occurred_at DESC, id DESC;
                """,
                (u_id,),
            )
            pending_events = [
                {
                    "id": str(r["id"]),
                    "bank_code": r["bank_code"],
                    "owner_account_snapshot": r["owner_account_snapshot"],
                    "amount_vnd": str(r["amount_vnd"]),
                    "direction": r["direction"],
                    "occurred_at": r["occurred_at"].isoformat(),
                    "time_source": r["time_source"],
                    "received_at": r["received_at"].isoformat(),
                    "bank_description": r["bank_description"],
                    "version": r["version"],
                }
                for r in cur.fetchall()
            ]

            # 6. Bank bindings
            cur.execute(
                f"""
                SELECT id, bank_code, account_number, version, capture_from, first_received_at
                FROM {schema}.bank_bindings
                WHERE user_id = %s
                ORDER BY bank_code ASC;
                """,
                (u_id,),
            )
            bank_bindings = [
                {
                    "id": str(r["id"]),
                    "bank_code": r["bank_code"],
                    "account_number": r["account_number"],
                    "version": r["version"],
                    "capture_from": r["capture_from"].isoformat() if r["capture_from"] else None,
                    "first_received_at": r["first_received_at"].isoformat() if r["first_received_at"] else None,
                }
                for r in cur.fetchall()
            ]

    return {
        "status": "snapshot",
        "revision": current_revision,
        "categories": categories,
        "tags": tags,
        "transactions": transactions,
        "pending_bank_events": pending_events,
        "bank_bindings": bank_bindings,
    }
