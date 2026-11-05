# Backend Deployment

The maintained service configuration and deployment instructions are in [Project Reference](../project.md#6-configuration). Use its [Mac mini setup](../project.md#7-run-on-the-mac-mini) and [recovery procedures](../project.md#8-backup-migration-and-recovery).

Both backend and broker must run. PostgreSQL remains on Supabase; pending event payloads reside in JetStream. Native templates are LaunchAgents for a logged-in Mac user, use Apple Silicon Homebrew paths and checkout-local logs, and expose only the HTTPS application gateway to clients. They are not a verified system-wide boot deployment.

For the production checkout currently deployed at `/Users/Shared/quanlytao-local`, install the system LaunchDaemons once so NATS, the API on port 8001, and Cloudflare Tunnel start during boot without waiting for an interactive login:

```bash
cd /Users/fendee/Documents/personal-management
./tool/backend.sh install
```

The installer asks for the macOS administrator password, validates and copies root-owned plists into `/Library/LaunchDaemons`, loads PostgreSQL, NATS, the API, and Cloudflare Tunnel in the system launchd domain, and enables `RunAtLoad` plus `KeepAlive`. Logs are stored under `/Users/Shared/quanlytao-local/logs`. Re-run the installer after changing a daemon template. The fixed paths and service account are specific to this Mac; update all templates together if the deployment location or account changes.

Daily operation uses one command from the repository root:

```bash
./tool/backend.sh restart  # restart the complete backend stack and verify health
./tool/backend.sh status   # show launchd state and both local/public health
./tool/backend.sh logs     # print log locations
```

The restart command requests the administrator password because the services run at system boot. It returns success only after both the local and public readiness endpoints respond successfully.
