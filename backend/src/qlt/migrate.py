import argparse
from pathlib import Path
import sys
import psycopg
from qlt.config import get_settings


def run_migrations(dsn: str | None = None, schema: str = "qlt") -> None:
    settings = get_settings()
    target_dsn = dsn or settings.database_url
    migrations_dir = Path(__file__).resolve().parents[2] / "migrations"

    if not migrations_dir.exists():
        print(f"Migrations directory not found: {migrations_dir}")
        return

    sql_files = sorted(migrations_dir.glob("*.sql"))
    if not sql_files:
        print("No migration files found.")
        return

    print(f"Connecting to database to run migrations on schema '{schema}'...")
    with psycopg.connect(target_dsn, autocommit=False) as conn:
        with conn.cursor() as cur:
            # Ensure schema and migration tracking table exist
            cur.execute(f"CREATE SCHEMA IF NOT EXISTS {schema};")
            cur.execute(
                f"""
                CREATE TABLE IF NOT EXISTS {schema}._migrations (
                    version TEXT PRIMARY KEY,
                    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                """
            )
            cur.execute(f"SELECT version FROM {schema}._migrations;")
            applied = {row[0] for row in cur.fetchall()}

            for sql_file in sql_files:
                version = sql_file.name
                if version in applied:
                    continue

                print(f"Applying migration: {version}")
                sql = sql_file.read_text(encoding="utf-8")
                # Execute migration
                cur.execute(sql)
                cur.execute(
                    f"INSERT INTO {schema}._migrations (version) VALUES (%s);",
                    (version,),
                )
                conn.commit()
                print(f"Applied: {version}")

    print("All migrations up to date.")


def main():
    parser = argparse.ArgumentParser(description="Run Quản lý Tao database migrations")
    parser.add_argument("--schema", default="qlt", help="Target schema name (default: qlt)")
    args = parser.parse_args()
    try:
        run_migrations(schema=args.schema)
    except Exception as e:
        print(f"Migration error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
