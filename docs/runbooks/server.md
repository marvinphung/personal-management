# Backend Deployment

The maintained service configuration and deployment instructions are in [Project Reference](../project.md#6-configuration). Use its [Mac mini setup](../project.md#7-run-on-the-mac-mini) and [recovery procedures](../project.md#8-backup-migration-and-recovery).

Both backend and broker must run. PostgreSQL remains on Supabase; pending event payloads reside in JetStream. Native templates are LaunchAgents for a logged-in Mac user, use Apple Silicon Homebrew paths and checkout-local logs, and expose only the HTTPS application gateway to clients. They are not a verified system-wide boot deployment.
