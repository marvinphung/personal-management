-- Epochs are routing metadata, never financial payloads. NULL means an older
-- reservation must be revalidated by its collector retry before recovery.
ALTER TABLE qlt.bank_event_receipts ADD COLUMN IF NOT EXISTS capture_epoch BIGINT;
ALTER TABLE qlt.bank_event_receipts ADD COLUMN IF NOT EXISTS binding_version BIGINT;
