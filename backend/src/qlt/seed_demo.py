"""Idempotently seed an approved local user and realistic demo finance data."""

import asyncio
import uuid
from datetime import datetime, timedelta, timezone

import psycopg
from psycopg.rows import dict_row

from qlt.auth.passwords import hash_password, normalize_username
from qlt.catalog.seeds import seed_user_defaults
from qlt.config import get_settings
from qlt.db import close_async_pool, init_async_pool
from qlt.messaging.client import close_nats, get_jetstream
from qlt.messaging.ingestion import CollectorEventItem, process_collector_events_async
from qlt.messaging.stream import ensure_stream

NAMESPACE = uuid.UUID("a3d7c0f4-c3c4-4a0b-90ca-b154b91a73c7")


def stable_id(name: str) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, name)


def seed_relational_data() -> tuple[uuid.UUID, uuid.UUID]:
    settings = get_settings()
    if not settings.demo_user_password:
        raise RuntimeError("DEMO_USER_PASSWORD must be set in .env")

    schema = settings.database_schema
    username = normalize_username(settings.demo_user_username)
    user_id = stable_id(f"user:{username}")
    binding_id = stable_id(f"binding:{username}:techcombank")
    now = datetime.now(timezone.utc)

    with psycopg.connect(settings.database_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {schema}.users
                    (id, username, password_hash, role, status, capture_enabled, must_change_password)
                VALUES (%s, %s, %s, 'user', 'active', true, false)
                ON CONFLICT (LOWER(username)) DO UPDATE SET
                    password_hash=EXCLUDED.password_hash,
                    role='user', status='active', capture_enabled=true,
                    must_change_password=false, deleted_at=NULL
                RETURNING id
                """,
                (str(user_id), username, hash_password(settings.demo_user_password)),
            )
            user_id = cur.fetchone()["id"]
            seed_user_defaults(conn, user_id)

            cur.execute(
                f"SELECT id, name_key FROM {schema}.categories WHERE user_id=%s",
                (str(user_id),),
            )
            categories = {row["name_key"]: row["id"] for row in cur.fetchall()}

            cur.execute(
                f"""
                INSERT INTO {schema}.user_revisions (user_id, revision, inbox_revision)
                VALUES (%s, 1, 0) ON CONFLICT (user_id) DO NOTHING
                """,
                (str(user_id),),
            )
            cur.execute(
                f"""
                INSERT INTO {schema}.bank_bindings
                    (id, user_id, bank_code, account_number, capture_from)
                VALUES (%s, %s, 'techcombank', '19031234567890', %s)
                ON CONFLICT (user_id, bank_code) DO UPDATE SET
                    account_number=EXCLUDED.account_number
                RETURNING id
                """,
                (str(binding_id), str(user_id), now - timedelta(days=60)),
            )
            binding_id = cur.fetchone()["id"]

            wallet_id = stable_id(f"wallet:{username}")
            cur.execute(
                f"""
                INSERT INTO {schema}.cash_wallets
                    (id, user_id, name, opening_amount_vnd, opening_at)
                VALUES (%s, %s, 'Ví tiền mặt', 2500000, %s)
                ON CONFLICT (id) DO NOTHING
                """,
                (str(wallet_id), str(user_id), now - timedelta(days=90)),
            )

            transactions = [
                ("salary", "income", 28000000, 3, "luong", "Lương tháng này", "bank"),
                ("rent", "expense", 6500000, 5, "nha_hoa_đon", "Tiền thuê nhà", "bank"),
                ("groceries", "expense", 735000, 2, "an_uong", "Đi chợ cuối tuần", "cash"),
                ("coffee", "expense", 65000, 1, "an_uong", "Cà phê với đồng nghiệp", "cash"),
                ("freelance", "income", 4500000, 12, "lam_them", "Dự án freelance", "bank"),
                ("fuel", "expense", 120000, 8, "đi_lai", "Đổ xăng", "cash"),
                ("cinema", "expense", 210000, 15, "giai_tri", "Xem phim", "manual"),
            ]
            for key, direction, amount, days, category_key, note, source in transactions:
                cur.execute(
                    f"""
                    INSERT INTO {schema}.transactions
                        (id, user_id, direction, amount_vnd, occurred_at, source,
                         bank_code_snapshot, owner_account_snapshot, bank_description,
                         category_id, user_note, source_event_key)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (source_event_key) DO NOTHING
                    """,
                    (
                        str(stable_id(f"transaction:{username}:{key}")),
                        str(user_id),
                        direction,
                        amount,
                        now - timedelta(days=days),
                        source,
                        "techcombank" if source == "bank" else None,
                        "...7890" if source == "bank" else None,
                        note if source == "bank" else None,
                        str(categories[category_key]),
                        note,
                        f"demo:{username}:{key}",
                    ),
                )

            person_id = stable_id(f"person:{username}:minh")
            debt_id = stable_id(f"debt:{username}:minh")
            cur.execute(
                f"""INSERT INTO {schema}.people (id,user_id,name,note)
                VALUES (%s,%s,'Minh','Bạn thân') ON CONFLICT (id) DO NOTHING""",
                (str(person_id), str(user_id)),
            )
            cur.execute(
                f"""INSERT INTO {schema}.debts
                (id,user_id,person_id,direction,principal_vnd,started_at,due_at,status)
                VALUES (%s,%s,%s,'lent',3000000,%s,%s,'active') ON CONFLICT (id) DO NOTHING""",
                (
                    str(debt_id),
                    str(user_id),
                    str(person_id),
                    now - timedelta(days=20),
                    now + timedelta(days=10),
                ),
            )
            cur.execute(
                f"""INSERT INTO {schema}.notes (id,user_id,content,pinned)
                VALUES (%s,%s,'Nhớ kiểm tra ngân sách du lịch cuối tháng',true)
                ON CONFLICT (id) DO NOTHING""",
                (str(stable_id(f"note:{username}:budget")), str(user_id)),
            )
            cur.execute(
                f"UPDATE {schema}.user_revisions SET revision=revision+1 WHERE user_id=%s",
                (str(user_id),),
            )
        conn.commit()
    return user_id, binding_id


async def seed_pending_events(user_id: uuid.UUID, binding_id: uuid.UUID) -> list[dict]:
    settings = get_settings()
    await init_async_pool()
    await ensure_stream(await get_jetstream())
    now = datetime.now(timezone.utc)
    events = [
        ("incoming", "income", "1250000", "NGUYEN VAN AN chuyen tien", "FT-DEMO-001"),
        ("shopping", "expense", "389000", "THANH TOAN SHOPEE VN", "FT-DEMO-002"),
        ("utility", "expense", "842000", "THANH TOAN HOA DON DIEN", "FT-DEMO-003"),
    ]
    items = [
        CollectorEventItem(
            event_id=str(stable_id(f"pending:{settings.demo_user_username}:{key}")),
            collector_epoch=1,
            binding_id=str(binding_id),
            binding_version=1,
            capture_epoch=1,
            bank_code="techcombank",
            owner_account="19031234567890",
            direction=direction,
            amount_vnd=amount,
            occurred_at=(now - timedelta(hours=index + 1)).isoformat(),
            time_source="demo_seed",
            bank_description=description,
            bank_reference=reference,
            source_package="app.quanlytao.demo",
            parser_version="demo-v1",
            source_event_key=f"demo:{settings.demo_user_username}:pending:{key}",
        )
        for index, (key, direction, amount, description, reference) in enumerate(events)
    ]
    try:
        # Do not regenerate an existing demo event with a new timestamp on reruns.
        from qlt.db import get_async_connection

        async with get_async_connection() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    f"SELECT id FROM {settings.database_schema}.bank_event_receipts "
                    "WHERE id = ANY(%s)",
                    ([item.event_id for item in items],),
                )
                existing_ids = {str(row["id"]) for row in await cur.fetchall()}
        missing_items = [item for item in items if item.event_id not in existing_ids]
        if not missing_items:
            return [{"event_id": item.event_id, "status": "already_seeded"} for item in items]
        return await process_collector_events_async(missing_items, {"epoch": 1})
    finally:
        await close_nats()
        await close_async_pool()


def main() -> None:
    user_id, binding_id = seed_relational_data()
    results = asyncio.run(seed_pending_events(user_id, binding_id))
    print(f"Seeded approved demo user {get_settings().demo_user_username!r} ({user_id})")
    print(f"Pending events: {results}")


if __name__ == "__main__":
    main()
