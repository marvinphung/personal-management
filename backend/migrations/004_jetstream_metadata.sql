-- Migration 004_jetstream_metadata.sql
-- NATS JetStream coordination schema: bank_event_receipts, metadata_outbox_jobs, push_devices, inbox revisions

-- 1. Add inbox_revision to user_revisions
ALTER TABLE qlt.user_revisions ADD COLUMN IF NOT EXISTS inbox_revision BIGINT NOT NULL DEFAULT 0;

-- 2. Bank Event Receipts (Supabase coordination and deduplication metadata)
CREATE TABLE IF NOT EXISTS qlt.bank_event_receipts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE RESTRICT,
    binding_id UUID REFERENCES qlt.bank_bindings(id) ON DELETE SET NULL,
    fingerprint TEXT UNIQUE NOT NULL REFERENCES qlt.ingest_receipts(fingerprint),
    stream_name TEXT,
    stream_seq BIGINT,
    state TEXT NOT NULL CHECK (state IN ('publishing', 'pending', 'accepted', 'discarded', 'purged')),
    payload_hash TEXT NOT NULL,
    first_received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    discarded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS bank_event_receipts_user_state_idx 
    ON qlt.bank_event_receipts (user_id, state, first_received_at DESC);

CREATE INDEX IF NOT EXISTS bank_event_receipts_stream_seq_idx 
    ON qlt.bank_event_receipts (stream_name, stream_seq) 
    WHERE stream_seq IS NOT NULL;

-- 3. Metadata Transactional Outbox Jobs
-- Retains coordination tasks (broker payload cleanup, realtime invalidations, push refreshes).
-- user_id does NOT cascade on delete so payload cleanup jobs survive hard purge long enough to run.
CREATE TABLE IF NOT EXISTS qlt.metadata_outbox_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind TEXT NOT NULL CHECK (kind IN ('payload_cleanup', 'realtime_invalidation', 'push_refresh')),
    user_id UUID NOT NULL,
    event_id UUID,
    stream_name TEXT,
    stream_seq BIGINT,
    inbox_revision BIGINT,
    attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 10,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    locked_until TIMESTAMPTZ,
    locked_by TEXT,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS metadata_outbox_jobs_status_attempt_idx 
    ON qlt.metadata_outbox_jobs (status, next_attempt_at) 
    WHERE status IN ('pending', 'processing');

CREATE INDEX IF NOT EXISTS metadata_outbox_jobs_user_idx 
    ON qlt.metadata_outbox_jobs (user_id, created_at);

-- 4. Push Devices Registration
CREATE TABLE IF NOT EXISTS qlt.push_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES qlt.users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    device_id TEXT NOT NULL,
    token TEXT NOT NULL,
    environment TEXT NOT NULL DEFAULT 'production',
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT push_devices_user_device_unique UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS push_devices_user_idx ON qlt.push_devices (user_id);

-- 5. RLS Policies
ALTER TABLE qlt.bank_event_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.bank_event_receipts FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bank_event_receipts_tenant_isolation ON qlt.bank_event_receipts;
CREATE POLICY bank_event_receipts_tenant_isolation ON qlt.bank_event_receipts FOR ALL
    USING (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid);

ALTER TABLE qlt.push_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.push_devices FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_devices_tenant_isolation ON qlt.push_devices;
CREATE POLICY push_devices_tenant_isolation ON qlt.push_devices FOR ALL
    USING (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid);

ALTER TABLE qlt.metadata_outbox_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE qlt.metadata_outbox_jobs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS metadata_outbox_jobs_tenant_isolation ON qlt.metadata_outbox_jobs;
CREATE POLICY metadata_outbox_jobs_tenant_isolation ON qlt.metadata_outbox_jobs FOR ALL
    USING (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid OR current_setting('app.user_id', true) IS NULL OR current_setting('app.user_id', true) = '')
    WITH CHECK (user_id = NULLIF(current_setting('app.user_id', true), '')::uuid OR current_setting('app.user_id', true) IS NULL OR current_setting('app.user_id', true) = '');

-- 6. Role grants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qlt_app') THEN
        GRANT ALL ON ALL TABLES IN SCHEMA qlt TO qlt_app;
        GRANT ALL ON ALL SEQUENCES IN SCHEMA qlt TO qlt_app;
    END IF;
END $$;
