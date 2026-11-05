-- Migration 001_schema.sql
-- Quản lý Tao core schema in schema 'qlt'

CREATE SCHEMA IF NOT EXISTS qlt;

-- Enable pgcrypto for UUID generation if needed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Users
CREATE TABLE IF NOT EXISTS qlt.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'deleted')),
    capture_enabled BOOLEAN NOT NULL DEFAULT true,
    capture_epoch BIGINT NOT NULL DEFAULT 1,
    must_change_password BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS users_username_key ON qlt.users (LOWER(username));

-- 2. Sessions
CREATE TABLE IF NOT EXISTS qlt.sessions (
    token_hash TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    scope TEXT NOT NULL DEFAULT 'user'
);
CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON qlt.sessions (user_id);

-- 3. Widget Tokens
CREATE TABLE IF NOT EXISTS qlt.widget_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS widget_tokens_user_id_idx ON qlt.widget_tokens (user_id);

-- 4. Bank Settings
CREATE TABLE IF NOT EXISTS qlt.bank_settings (
    bank_code TEXT PRIMARY KEY CHECK (bank_code IN ('bidv', 'vietinbank', 'vietcombank', 'techcombank')),
    enabled BOOLEAN NOT NULL DEFAULT true,
    receiver_account TEXT,
    receiver_name TEXT,
    instructions TEXT,
    version INT NOT NULL DEFAULT 1
);

-- 5. Bank Bindings
CREATE TABLE IF NOT EXISTS qlt.bank_bindings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    bank_code TEXT NOT NULL REFERENCES qlt.bank_settings(bank_code),
    account_number TEXT NOT NULL,
    version INT NOT NULL DEFAULT 1,
    capture_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    first_received_at TIMESTAMPTZ,
    CONSTRAINT bank_bindings_user_bank_unique UNIQUE (user_id, bank_code),
    CONSTRAINT bank_bindings_bank_account_unique UNIQUE (bank_code, account_number)
);

-- 6. Collector Devices
CREATE TABLE IF NOT EXISTS qlt.collector_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credential_hash TEXT UNIQUE NOT NULL,
    state TEXT NOT NULL DEFAULT 'active' CHECK (state IN ('active', 'retired')),
    epoch BIGINT NOT NULL DEFAULT 1,
    last_heartbeat_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS collector_one_active_idx ON qlt.collector_devices (state) WHERE state = 'active';

-- 7. Ingest Receipts (HMAC only, no content)
CREATE TABLE IF NOT EXISTS qlt.ingest_receipts (
    fingerprint TEXT PRIMARY KEY,
    algorithm_version TEXT NOT NULL DEFAULT 'v1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Pending Bank Events
CREATE TABLE IF NOT EXISTS qlt.pending_bank_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    binding_id UUID REFERENCES qlt.bank_bindings(id) ON DELETE SET NULL,
    bank_code TEXT NOT NULL,
    owner_account_snapshot TEXT NOT NULL,
    amount_vnd BIGINT NOT NULL CHECK (amount_vnd > 0 AND amount_vnd <= 9000000000000000),
    direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
    occurred_at TIMESTAMPTZ NOT NULL,
    time_source TEXT NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    bank_description TEXT NOT NULL,
    fingerprint TEXT UNIQUE NOT NULL REFERENCES qlt.ingest_receipts(fingerprint),
    parser_version TEXT NOT NULL,
    version INT NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS pending_bank_events_user_occurred_idx ON qlt.pending_bank_events (user_id, occurred_at DESC, id DESC);

-- 9. Categories
CREATE TABLE IF NOT EXISTS qlt.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
    name TEXT NOT NULL,
    name_key TEXT NOT NULL,
    icon TEXT,
    archived BOOLEAN NOT NULL DEFAULT false,
    seed_rank INT NOT NULL DEFAULT 999,
    behavior TEXT NOT NULL DEFAULT 'normal',
    version INT NOT NULL DEFAULT 1,
    CONSTRAINT categories_user_dir_name_unique UNIQUE (user_id, direction, name_key)
);

-- 10. Tags
CREATE TABLE IF NOT EXISTS qlt.tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES qlt.categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    name_key TEXT NOT NULL,
    archived BOOLEAN NOT NULL DEFAULT false,
    version INT NOT NULL DEFAULT 1,
    CONSTRAINT tags_user_cat_name_unique UNIQUE (user_id, category_id, name_key)
);

-- 11. Cash Wallets
CREATE TABLE IF NOT EXISTS qlt.cash_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    opening_amount_vnd BIGINT NOT NULL DEFAULT 0,
    opening_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1
);

-- 12. Ledger Transactions
CREATE TABLE IF NOT EXISTS qlt.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
    amount_vnd BIGINT NOT NULL CHECK (amount_vnd > 0 AND amount_vnd <= 9000000000000000),
    occurred_at TIMESTAMPTZ NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('bank', 'cash', 'manual')),
    bank_code_snapshot TEXT,
    owner_account_snapshot TEXT,
    bank_description TEXT,
    category_id UUID NOT NULL REFERENCES qlt.categories(id) ON DELETE RESTRICT,
    user_note TEXT NOT NULL DEFAULT '',
    purpose TEXT NOT NULL DEFAULT 'normal' CHECK (purpose IN ('normal', 'debt_principal', 'installment_payment')),
    cash_wallet_id UUID REFERENCES qlt.cash_wallets(id) ON DELETE SET NULL,
    version INT NOT NULL DEFAULT 1,
    source_event_key TEXT UNIQUE
);
CREATE INDEX IF NOT EXISTS transactions_user_occurred_idx ON qlt.transactions (user_id, occurred_at DESC, id DESC);

-- 13. Transaction Tags
CREATE TABLE IF NOT EXISTS qlt.transaction_tags (
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES qlt.transactions(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES qlt.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (transaction_id, tag_id)
);

-- 14. People (for debts)
CREATE TABLE IF NOT EXISTS qlt.people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    note TEXT,
    version INT NOT NULL DEFAULT 1
);

-- 15. Debts
CREATE TABLE IF NOT EXISTS qlt.debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES qlt.people(id) ON DELETE CASCADE,
    direction TEXT NOT NULL CHECK (direction IN ('lent', 'borrowed')),
    principal_vnd BIGINT NOT NULL CHECK (principal_vnd > 0),
    started_at TIMESTAMPTZ NOT NULL,
    due_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'settled')),
    version INT NOT NULL DEFAULT 1
);

-- 16. Debt Payments
CREATE TABLE IF NOT EXISTS qlt.debt_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    debt_id UUID NOT NULL REFERENCES qlt.debts(id) ON DELETE CASCADE,
    amount_vnd BIGINT NOT NULL CHECK (amount_vnd > 0),
    paid_at TIMESTAMPTZ NOT NULL,
    transaction_id UUID UNIQUE NOT NULL REFERENCES qlt.transactions(id) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1
);

-- 17. Debt Disbursements
CREATE TABLE IF NOT EXISTS qlt.debt_disbursements (
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    debt_id UUID NOT NULL REFERENCES qlt.debts(id) ON DELETE CASCADE,
    transaction_id UUID UNIQUE NOT NULL REFERENCES qlt.transactions(id) ON DELETE CASCADE,
    PRIMARY KEY (debt_id, transaction_id)
);

-- 18. Installment Plans
CREATE TABLE IF NOT EXISTS qlt.installment_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category_id UUID NOT NULL REFERENCES qlt.categories(id) ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    period_count INT NOT NULL CHECK (period_count > 0),
    version INT NOT NULL DEFAULT 1
);

-- 19. Installment Items
CREATE TABLE IF NOT EXISTS qlt.installment_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES qlt.installment_plans(id) ON DELETE CASCADE,
    sequence INT NOT NULL,
    due_date DATE NOT NULL,
    expected_vnd BIGINT NOT NULL CHECK (expected_vnd > 0),
    version INT NOT NULL DEFAULT 1,
    CONSTRAINT installment_items_plan_seq_unique UNIQUE (plan_id, sequence)
);

-- 20. Installment Payments
CREATE TABLE IF NOT EXISTS qlt.installment_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES qlt.installment_items(id) ON DELETE CASCADE,
    transaction_id UUID UNIQUE NOT NULL REFERENCES qlt.transactions(id) ON DELETE CASCADE,
    amount_vnd BIGINT NOT NULL CHECK (amount_vnd > 0)
);

-- 21. Cash Adjustments
CREATE TABLE IF NOT EXISTS qlt.cash_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    wallet_id UUID NOT NULL REFERENCES qlt.cash_wallets(id) ON DELETE CASCADE,
    delta_vnd BIGINT NOT NULL,
    at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 1
);

-- 22. Notes (secondary feature)
CREATE TABLE IF NOT EXISTS qlt.notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    pinned BOOLEAN NOT NULL DEFAULT false,
    version INT NOT NULL DEFAULT 1
);

-- 23. User Revisions
CREATE TABLE IF NOT EXISTS qlt.user_revisions (
    user_id UUID PRIMARY KEY REFERENCES qlt.users(id) ON DELETE CASCADE,
    revision BIGINT NOT NULL DEFAULT 1
);

-- 24. Operation Receipts (idempotency, no content)
CREATE TABLE IF NOT EXISTS qlt.operation_receipts (
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    operation_id UUID NOT NULL,
    request_hash TEXT NOT NULL,
    outcome_code TEXT NOT NULL,
    result_entity_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, operation_id)
);

-- 25. Admin Audit (no financial content or passwords)
CREATE TABLE IF NOT EXISTS qlt.admin_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID,
    action TEXT NOT NULL,
    target_id UUID,
    at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    outcome TEXT NOT NULL
);
