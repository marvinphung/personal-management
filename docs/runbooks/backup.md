# Runbook: Backup, Restore, and Secret Rotation

This runbook documents how to back up and restore `quanlytao` data, isolate the application schema from other databases, and rotate secrets safely.

---

## 1. Scope and Isolation Guarantee

All application state is housed strictly within the `qlt` schema:
- `qlt.users`, `qlt.sessions`, `qlt.widget_tokens`
- `qlt.bank_settings`, `qlt.bank_accounts`
- `qlt.pending_bank_events`, `qlt.ledger_transactions`
- `qlt.categories`, `qlt.tags`
- `qlt.people`, `qlt.debts`, `qlt.debt_payments`, `qlt.wallets`

> [!CRITICAL]
> **Never dump or restore the `public` schema indiscriminately.** Backup and restore operations MUST target only the `qlt` schema.

---

## 2. Creating a Database Backup

Run `pg_dump` targeting only the `qlt` schema:

```bash
# Set database URL or pass flags
export DATABASE_URL="postgresql://postgres:secret@db.example.com:5432/postgres?sslmode=require"

# Create compressed schema + data dump
pg_dump \
  --dbname="$DATABASE_URL" \
  --schema=qlt \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="backup_qlt_$(date +%Y%m%d_%H%M%S).dump"
```

To take a plain SQL dump:

```bash
pg_dump \
  --dbname="$DATABASE_URL" \
  --schema=qlt \
  --format=plain \
  --no-owner \
  --no-privileges \
  --file="backup_qlt_$(date +%Y%m%d_%H%M%S).sql"
```

---

## 3. Restoring from Backup

To restore into a fresh database or recovery instance:

```bash
# Create custom dump restore
pg_restore \
  --dbname="$TARGET_DATABASE_URL" \
  --schema=qlt \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  backup_qlt_YYYYMMDD_HHMMSS.dump
```

Or for plain SQL:

```bash
psql "$TARGET_DATABASE_URL" -f backup_qlt_YYYYMMDD_HHMMSS.sql
```

After restore, verify database readiness:

```bash
curl http://localhost:8000/v1/health/ready
```

---

## 4. Deduplication Key Backup & Separation

The `DEDUP_KEY` environment variable is used to compute stable hashes for bank transaction deduplication across restarts.

- **Storage:** Back up `DEDUP_KEY` in a secure password vault (e.g. 1Password, Bitwarden, Keepass), separate from database SQL dumps.
- **Rotation Rule:** **Do NOT rotate `DEDUP_KEY` routinely.** Rotating `DEDUP_KEY` causes existing deduplication hashes in the database to differ from newly computed incoming hashes, which could cause previously processed bank transactions to re-import if re-transmitted by the bank.

---

## 5. Collector Credential Rotation

If a collector phone is compromised or rotated:

1. Generating a new collector session automatically increments the active collector epoch in `qlt.collectors`.
2. Old collector sessions are immediately invalidated.
3. Rotating collector credentials **does NOT require changing `DEDUP_KEY`**.
