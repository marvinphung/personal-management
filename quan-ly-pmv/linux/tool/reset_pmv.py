"""Scoped reset tool for Quản lý PMV v1 data.

SAFETY RULES:
- Defaults to DRY-RUN mode.
- Deletion requires the explicit --execute flag.
- Requires --user-id argument (UUID format validated).
- Deletes ONLY from allowlisted v1 tables for the specified user_id.
- NEVER drops schemas, never touches auth.users, never touches qlt.* or other schemas.
- Never prints or logs connection secrets or DSNs.
"""

import argparse
from pathlib import Path
import os
import sys
import uuid
from dotenv import load_dotenv

# Allowlisted tables in FK-safe deletion order
V1_TABLES_ALLOWLIST = [
    'notes',
    'transaction_tags',
    'debt_payments',
    'debts',
    'transactions',
    'tags',
    'categories',
    'accounts',
    'people',
    'finance_operations',
]

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / '.env')


def validate_uuid(value: str) -> str:
    try:
        val = uuid.UUID(value)
        return str(val)
    except ValueError:
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid UUID")


def reset_user(conn, user_id: str, *, execute: bool = False, seed: bool = False):
    """Caller owns the transaction; all deletes and seed commit or roll back together."""
    user_id = validate_uuid(user_id)
    if not conn.execute('select 1 from auth.users where id=%s', (user_id,)).fetchone():
        raise ValueError('Target user does not exist')
    if execute:
        conn.execute('select pg_advisory_xact_lock(hashtextextended(%s,7139))', (user_id,))
    counts = {table: conn.execute(f'select count(*) from public.{table} where user_id=%s', (user_id,)).fetchone()[0]
              for table in V1_TABLES_ALLOWLIST}
    if execute:
        for table in V1_TABLES_ALLOWLIST:
            conn.execute(f'delete from public.{table} where user_id=%s', (user_id,))
        if seed:
            conn.execute('select public.finance_pmv_defaults(%s::uuid)', (user_id,))
    return counts


def main():
    parser = argparse.ArgumentParser(
        description="Scoped reset tool for Quản lý PMV v1 data."
    )
    parser.add_argument(
        '--user-id',
        required=True,
        type=validate_uuid,
        help="Target user UUID (required)",
    )
    parser.add_argument(
        '--execute',
        action='store_true',
        default=False,
        help="Actually execute deletion (default is dry-run)",
    )
    parser.add_argument(
        '--seed',
        action='store_true',
        default=False,
        help="Re-seed PMV default categories and tags after reset",
    )
    args = parser.parse_args()

    target_user_id = args.user_id
    is_dry_run = not args.execute

    print("=" * 60)
    print("QUẢN LÝ PMV — V1 DATA RESET TOOL")
    print(f"Target User UUID: {target_user_id}")
    print(f"Mode: {'DRY-RUN (no changes will be committed)' if is_dry_run else 'LIVE EXECUTION'}")
    print("=" * 60)

    try:
        import psycopg
    except ImportError:
        print("Error: psycopg is required. Install via 'pip install psycopg[binary]'", file=sys.stderr)
        sys.exit(1)

    try:
        options = dict(sslmode='require', connect_timeout=15)
        url = os.environ.get('SUPABASE_DATABASE_URL', '')
        if url:
            conn = psycopg.connect(url, **options)
        else:
            conn = psycopg.connect(
                host=os.environ['SUPABASE_DB_HOST'],
                port=os.environ.get('SUPABASE_DB_PORT', '5432'),
                dbname=os.environ.get('SUPABASE_DB_NAME', 'postgres'),
                user=os.environ['SUPABASE_DB_USER'],
                password=os.environ['SUPABASE_DB_PASSWORD'],
                **options,
            )

        with conn:
            counts = reset_user(conn, target_user_id, execute=not is_dry_run, seed=args.seed)
            for table, count in counts.items():
                print(f"  public.{table:<20}: {count} matching rows")
        # Success is printed only after transaction commit.
        print("[DRY-RUN COMPLETE] No rows were deleted." if is_dry_run
              else "[EXECUTION COMPLETE] Scoped reset committed.")

    except Exception as exc:
        print(
            f"Reset operation failed ({type(exc).__name__}). Check credentials or connectivity.",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == '__main__':
    main()
