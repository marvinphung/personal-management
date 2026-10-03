-- Migration 002_roles.sql
-- Permissions and RLS for schema 'qlt'

-- 1. Revoke public/anon access on schema
REVOKE ALL ON SCHEMA qlt FROM PUBLIC;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE ALL ON SCHEMA qlt FROM anon;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE ALL ON SCHEMA qlt FROM authenticated;
    END IF;
END $$;

-- 2. Enable RLS on user-owned tables
ALTER TABLE qlt.pending_bank_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.bank_bindings ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.cash_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.transaction_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.people ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.debt_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.debt_disbursements ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.installment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.installment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.installment_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.cash_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.user_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.operation_receipts ENABLE ROW LEVEL SECURITY;

-- 3. RLS Isolation Policies using transaction-local app.user_id
DO $$
DECLARE
    t text;
    tables text[] := ARRAY[
        'pending_bank_events', 'bank_bindings', 'categories', 'tags',
        'cash_wallets', 'transactions', 'transaction_tags', 'people',
        'debts', 'debt_payments', 'debt_disbursements', 'installment_plans',
        'installment_items', 'installment_payments', 'cash_adjustments',
        'notes', 'user_revisions', 'operation_receipts'
    ];
BEGIN
    FOREACH t IN ARRAY tables LOOP
        EXECUTE format('ALTER TABLE qlt.%I FORCE ROW LEVEL SECURITY;', t);
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON qlt.%I;',
            t || '_tenant_isolation', t
        );
        EXECUTE format(
            'CREATE POLICY %I ON qlt.%I FOR ALL USING (user_id = NULLIF(current_setting(''app.user_id'', true), '''')::uuid) WITH CHECK (user_id = NULLIF(current_setting(''app.user_id'', true), '''')::uuid);',
            t || '_tenant_isolation', t
        );
    END LOOP;
END $$;

-- 4. Application runtime role without BYPASSRLS
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qlt_app') THEN
        CREATE ROLE qlt_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
    END IF;
    GRANT USAGE ON SCHEMA qlt TO qlt_app;
    GRANT ALL ON ALL TABLES IN SCHEMA qlt TO qlt_app;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA qlt TO qlt_app;
END $$;

