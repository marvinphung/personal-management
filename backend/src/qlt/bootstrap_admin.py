import argparse
import getpass
import sys
import uuid
import psycopg
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher
from qlt.config import get_settings

password_hash_helper = PasswordHash((Argon2Hasher(),))


def bootstrap_admin(username: str, password: str | None = None) -> None:
    settings = get_settings()
    username = username.strip().lower()
    if not username:
        raise ValueError("Username cannot be empty")

    if not password:
        password = getpass.getpass(f"Enter password for admin '{username}': ")
        password_confirm = getpass.getpass("Confirm password: ")
        if password != password_confirm:
            print("Error: Passwords do not match.", file=sys.stderr)
            sys.exit(1)

    if len(password) < 8 or len(password) > 128:
        print("Error: Password must be between 8 and 128 characters.", file=sys.stderr)
        sys.exit(1)

    hashed = password_hash_helper.hash(password)
    user_id = uuid.uuid4()

    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.users (
                    id, username, password_hash, role, status, capture_enabled, must_change_password
                ) VALUES (%s, %s, %s, 'admin', 'active', true, false)
                ON CONFLICT (LOWER(username)) DO UPDATE SET
                    password_hash = EXCLUDED.password_hash,
                    role = 'admin',
                    status = 'active',
                    must_change_password = false;
                """,
                (str(user_id), username, hashed),
            )
    print(f"Administrator '{username}' successfully bootstrapped.")


def main():
    parser = argparse.ArgumentParser(description="Bootstrap an administrator account")
    parser.add_argument("username", help="Administrator username")
    parser.add_argument("--password", help="Administrator password (prompted if omitted)", default=None)
    args = parser.parse_args()
    try:
        bootstrap_admin(args.username, args.password)
    except Exception as e:
        print(f"Bootstrap error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
