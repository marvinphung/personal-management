# JetStream Migration and Recovery

Use [Project Reference — Backup, migration and recovery](../project.md#8-backup-migration-and-recovery).

Apply migrations through `005_receipt_fencing.sql` before deploying. Migration dry-run is read-only with respect to SQL and broker configuration. Pause application writes during migration, verify payload/receipt parity, and keep terminal deduplication identifiers. There is no `ENABLE_JETSTREAM=false` fallback; reverting after new events requires data reconciliation.
