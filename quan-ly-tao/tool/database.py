"""Developer-only PostgreSQL administration. Never imported by either client."""
import argparse
from pathlib import Path
import os
import sys
from dotenv import load_dotenv
import psycopg

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / '.env')
parser = argparse.ArgumentParser()
parser.add_argument('command', choices=['inspect', 'migrate', 'test'])
args = parser.parse_args()
try:
    options = dict(sslmode='require', connect_timeout=15)
    url = os.environ.get('SUPABASE_DATABASE_URL', '')
    if url:
        conn = psycopg.connect(url, **options)
    else:
        conn = psycopg.connect(host=os.environ['SUPABASE_DB_HOST'],
            port=os.environ.get('SUPABASE_DB_PORT', '5432'),
            dbname=os.environ.get('SUPABASE_DB_NAME', 'postgres'),
            user=os.environ['SUPABASE_DB_USER'],
            password=os.environ['SUPABASE_DB_PASSWORD'], **options)
    with conn:
        tables = conn.execute("select tablename from pg_tables where schemaname='public' order by tablename").fetchall()
        print('Public tables:', ', '.join(t[0] for t in tables) or '(empty)')
        if args.command == 'migrate':
            conn.execute('select pg_advisory_xact_lock(713908452)')
            conn.execute('create table if not exists public.finance_schema_migrations (version text primary key, applied_at timestamptz not null default now())')
            conn.execute('revoke all on public.finance_schema_migrations from anon, authenticated')
            for file in sorted((ROOT / 'linux/supabase/migrations').glob('*.sql')):
                if not conn.execute('select 1 from public.finance_schema_migrations where version=%s', (file.name,)).fetchone():
                    conn.execute(file.read_text())
                    conn.execute('insert into public.finance_schema_migrations(version) values(%s)', (file.name,))
                    print('Applied:', file.name)
        elif args.command == 'test':
            for file in sorted((ROOT / 'linux/supabase/tests').glob('*.sql')):
                conn.execute(file.read_text())
                print('Passed:', file.name)
            conn.rollback()
except Exception as exc:
    # Driver messages can contain DSNs or values. Deliberately report class only.
    print(f'Database operation failed ({type(exc).__name__}). Check credentials, SSL, connectivity, or schema compatibility.', file=sys.stderr)
    sys.exit(1)
