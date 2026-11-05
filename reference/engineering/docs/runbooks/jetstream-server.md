# JetStream Server Operations

Use [Project Reference — Configuration](../project.md#6-configuration), [Run on the Mac mini](../project.md#7-run-on-the-mac-mini), and [Backup and recovery](../project.md#8-backup-migration-and-recovery).

The native service loads private broker credentials through `qlt.messaging.run_nats`; storage is `data/jetstream` under the checkout. Monitoring and broker ports are private. A live-directory tar is not a consistent backup. Mac launchd deployment remains to be validated on the actual Mac.
