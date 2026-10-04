# Quản lý Tao — Project Reference

Updated: 2026-10-04. This is the maintained project description, replacing the implementation plans. It records the agreed product, backend behavior, configuration and operating procedures. Mobile UX and native background behavior described here are requirements; they have not been revalidated in this backend-only repair session.

## 1. Purpose and components

Quản lý Tao helps a small group of users classify bank income/expense into their personal spending records. Initially fewer than five users share automatic bank transaction notifications with the administrator's bank accounts. A Mac mini M1 (8 GB RAM / 256 GB SSD) runs FastAPI and a persistent NATS JetStream broker; Supabase hosts PostgreSQL.

| Component | Location | Responsibility |
|---|---|---|
| User app, Android and iOS | `apps/user_app`, `packages/finance_core` | Personal ledger, bank inbox, categories/tags, local cache and offline commands, count widget |
| Collector/admin app, Android | `apps/collector_app` | Bank notification listener, parsers, durable upload queue, collector status and administration |
| Shared mobile API client | `packages/api_client` | HTTP authentication/commands and authenticated foreground WebSocket |
| Backend | `backend/src/qlt` | Authentication, permissions, routing, deduplication, ledger resolution, snapshots, realtime and push |
| PostgreSQL | Supabase, schema `qlt` | Users, bank links, ledger and coordination metadata |
| Broker | Native NATS or `deploy/compose.yaml` | Pending bank payloads in a private persistent file store |

The collector and user app have separate IDs (`app.quanlytao.collector`, `app.quanlytao.user`) and can coexist on one Android phone. The administrator uses the regular user app for their own finances. The collector can later move to a dedicated Android phone. The Linux desktop app is retired.

## 2. User and administrator flows

### Registration and bank setup

1. Register with username, password and password confirmation. No email or phone number is required. Password confirmation is a client validation; the API receives username/password.
2. The account starts pending. The administrator approves the user once through the collector app. Approval seeds personal categories and tags.
3. The user selects a bank and enters their own full account number. There is one account per bank per user, and multiple banks are allowed.
4. Show the administrator's configured receiving account and bank-specific sharing instructions. The user enables automatic notification sharing inside the bank app.
5. Capture becomes demonstrably connected after the first matching event arrives (`first_received_at`); completing the instructions alone is not proof.

A `(bank_code, account_number)` pair is globally unique, including soft-deleted users. A conflict displays “Số tài khoản này đã được đăng ký” without identifying the owner. Account numbers are strings; preserve leading zeros. Users can replace a linked account with another unique account. Its binding version increments and old collector submissions are fenced. Historical transactions keep their original source snapshot.

### Daily use

The four tabs are **Tổng quan / Thu chi / Biến động / Cài đặt**. The bank inbox shows income and expense from all linked banks with transaction time, signed amount, bank/account and original bank description. Reports include recorded ledger entries, not pending notifications. Display no bank balance.

The common classification flow is: widget → inbox → Chấp nhận → category → optional tag → final Chấp nhận. With one tag this takes five taps. Amount, direction, bank, time and original bank content are read-only. Category is required; tags and a separate personal note are optional. Both income and expense support tags.

Show categories immediately: two rows of three controls containing the user's five most-used categories and “Khác…”. Rank income and expense separately using recorded transactions; use default order to fill unused positions. “Khác…” opens the full list and inline category creation. Tags also support inline creation. Preserve the classification draft when creating either item. Extended flows may take more than five taps.

On **Bỏ qua**, immediately hide the item and show “Đã bỏ qua giao dịch −500k” with **Hoàn tác** and a three-second countdown. A second discard finalizes the first and starts a new undo window. The undo slot and deadline are stored locally. After expiry, enqueue a durable discard command. There is no dismissal history or restore after finalization. Acceptance creates a ledger entry and removes the pending payload; accepted ledger data remains available for reports and permitted category/tag/note edits.

For transfers between a user's own accounts, the user discards both notifications. Automatic internal-transfer matching is outside current scope. Manual cash income/expense and an optional cash wallet remain available. Debt, repayment, installment and note functions are secondary flows, reached through the app rather than a Công nợ bottom tab.

### Default categories and tags

| Expense category | Initial tags |
|---|---|
| Ăn uống | Ăn sáng, Ăn trưa, Ăn tối, Cà phê |
| Đi lại | Xăng xe, Gửi xe, Taxi, Xe công nghệ |
| Mua sắm | Quần áo, Đồ cá nhân, Đồ gia dụng |
| Nhà & hóa đơn | Tiền nhà, Điện, Nước, Internet |
| Giải trí | Xem phim, Game, Đi chơi |
| Sức khỏe | Thuốc, Khám bệnh, Thể thao |
| Học tập | Học phí, Sách, Khóa học |
| Gia đình & quà tặng | Gia đình, Quà tặng, Hiếu hỉ |
| Du lịch | Vé xe/máy bay, Lưu trú |
| Chi khác | None required |

| Income category | Initial tags |
|---|---|
| Lương | Lương chính, Phụ cấp, Làm thêm giờ |
| Thưởng | Thưởng tháng, Thưởng quý, Thưởng Tết |
| Kinh doanh | Bán hàng, Dịch vụ |
| Làm thêm | Freelance, Dạy học, Công việc phụ |
| Được tặng | Gia đình, Bạn bè, Mừng tuổi |
| Thu khác | Hoàn tiền, Khác |

The “Khác…” grid control opens the catalog; it is distinct from the real categories “Chi khác” and “Thu khác”. Seeds are implemented in `backend/src/qlt/catalog/seeds.py`; users can extend their own catalog.

### Administrator lifecycle

- Approve pending accounts; enable/disable capture independently of manual finance use.
- Set a temporary password, revoke old sessions, and require a password change at next login.
- Soft-delete into **Tài khoản đã xóa**. Retain data and bank-account reservations; block login and capture. No timed automatic purge.
- Restore a deleted account, or explicitly purge its data later.
- Purge holds a deleted-user lock while deleting all broker subjects for that user, including messages published before a lost ACK with no stored sequence. Only after broker confirmation does it delete SQL user data and release username/account reservations. A broker failure returns HTTP 503 and keeps the deleted account for retry. Partial broker deletion is safe to retry; it never reports final success without confirmation.
- Preserve the payload-free HMAC deduplication identifiers after purge so old collector events cannot create new entries. No discarded amounts/descriptions are retained in these identifiers.

Multiple user devices are supported. A shared, idempotent backend resolution service makes the first committed accept/discard win.

## 3. Bank capture rules

Supported bank identifiers: `bidv`, `vietinbank`, `vietcombank`, `techcombank`. **MB Bank is excluded** because the example masks the owning account. Actual bank parser/package support still requires device fixtures and Android validation.

Only successful VND transactions with an unmasked owning account can route to an enabled registry binding. Read the owning-account field, not a counterparty account found in transfer content. Never match suffixes or guess masked accounts. Ignore unregistered/ambiguous accounts, marketing, OTP, failed transactions, unsupported currencies and balances. Keep diagnostic counters/reason codes rather than raw unmatched notifications.

The collector uses Android's notification listener and a persistent local queue, not an always-open Flutter screen. `accepted`, `duplicate` and `dropped` are terminal upload acknowledgments; `retry` keeps the collector queue item. Backend processing requires a valid collector epoch, active capture-enabled user, matching capture epoch, bank account and binding version.

Force-stop, revoked permissions, OEM battery restrictions and notifications never delivered to the listener can interrupt capture. Broker persistence cannot reconstruct bank notifications the collector never received.

## 4. Data flow and storage

```mermaid
flowchart LR
  B[Bank notifications on collector Android] --> C[Parser and durable local upload queue]
  C -->|HTTPS POST collector/events| A[FastAPI backend]
  A <-->|Identity, ledger, receipts and outbox| D[(Supabase PostgreSQL)]
  A <-->|Pending immutable payloads| J[(Private NATS JetStream file store)]
  A -->|Authenticated foreground WebSocket snapshots| U[Android / iOS user app]
  U <-->|REST commands and recovery snapshot| A
  U --> L[(Per-user SQLite, undo slot and command outbox)]
  L --> W[Count widget]
  A --> P[APNs / FCM count-refresh signal]
  P -->|OS-controlled delivery| U
```

Mobile apps do not connect to NATS or Supabase directly. Broker subjects contain internal UUIDs, not account numbers:

```text
Stream: QLT_<ENVIRONMENT_UPPERCASE>_PENDING_V1
Subject: qlt.<environment>.pending.<user_uuid>.<event_uuid>
Nats-Msg-Id: qlt-event-<event_uuid>
```

### Storage ownership

| Store | Contents and lifetime |
|---|---|
| Collector local queue | Normalized unsent notifications; retained until a terminal backend ACK |
| JetStream | Immutable financial payload while pending; explicit deletion after resolution/purge |
| `qlt.bank_event_receipts` | Event/user/binding IDs, fingerprint, payload hash, state, stream locator, fencing epochs and timestamps; no amount/account text/description |
| `qlt.ingest_receipts` | HMAC deduplication identifiers, retained beyond broker duplicate window and hard purge |
| `qlt.metadata_outbox_jobs` | Metadata-only cleanup/realtime/push jobs and leases |
| `qlt.transactions`, `transaction_tags` | Accepted/manual ledger entries and classification |
| Other SQL tables | Users, sessions, widget tokens, bank settings/bindings, categories/tags, revisions, push devices and secondary finance data |
| User SQLite | Downloaded pending inbox, ledger/catalog cache, durable offline command outbox and one active undo slot |

Pending payload storage moved to JetStream; the system still writes SQL coordination metadata. Accepted ledger data belongs in PostgreSQL. Legacy `pending_bank_events` rows can remain from migration and must not be treated as the current inbox or automatic rollback source.

### Ingestion and recovery

1. Validate input (positive integer VND within signed 64-bit range, income/expense direction, UUIDs and timezone-aware time) and routing fences.
2. Compute the HMAC fingerprint and reserve a committed `publishing` receipt. Existing terminal receipts or hard-purged fingerprints suppress duplicates.
3. Revalidate routing under shared user/binding locks; lock user revision then the receipt. Keep these locks through bounded broker reads/publication.
4. Look up the exact event subject before publishing. If a lost ACK left its payload in JetStream, verify identity/content and reuse its sequence. Otherwise publish with a stable message ID.
5. Conditionally transition only `publishing → pending`. Store the locator, bump revisions and enqueue realtime/push jobs in the same SQL transaction. Return terminal `accepted` only after commit.
6. A coordinator checks old `publishing` receipts every 30 seconds, reacquires locks, rechecks state/fencing, verifies the stored payload, then commits it. A terminal event can never be changed back to pending. Stale reservations are suppressed and cleaned. Pre-migration reservations with unknown fencing await a valid collector retry.

Fencing metadata is added by migration `005_receipt_fencing.sql`. Apply it before deploying this backend version. User capture epoch and binding version are retained in receipts so pause/resume or account replacement cannot silently recover an obsolete reservation.

### Acceptance, discard and cleanup

Direct HTTP resolution and offline sync operations call `messaging/resolution.py`. The service locks user → revision → event receipt, then checks the operation receipt under the serialization lock. Same operation/content replays its result; changed content with the same operation ID conflicts. Another device's already committed resolution returns `already_resolved`.

Accept retrieves the immutable broker payload and verifies subject, event/user/binding identity and hash. Category must belong to the user and match direction; tags must belong to that category. Ledger insert, terminal state, operation receipt, revisions and cleanup/delivery outbox jobs commit atomically. Discard skips ledger insertion. Processing a still-publishing event returns a retryable conflict.

After commit, attempt exact-event-subject cleanup immediately. The durable outbox retries it after outages; cleanup does not give up at the ordinary ten-attempt notification limit. Exact-subject purge is idempotent after a lost delete ACK and cannot delete another event because of a stale sequence. A stale worker cannot complete/fail a lease now owned by another worker.

### Foreground realtime, recovery and widgets

`/v1/realtime` authenticates with the HTTP Bearer session header. Backend derives the user; clients never choose arbitrary subjects. Initial delivery is `hello` then an authoritative `inbox.snapshot`. Large snapshots use begin/chunk/end frames at a configurable 256 KiB threshold. Snapshot assembly rechecks inbox revision; exhausted drift retries return HTTP 503 rather than labeling old data with a newer revision. Empty snapshots also undergo revision verification. Missing, corrupted or misrouted payloads fail the snapshot rather than disappearing from it.

Per-user send serialization prevents snapshot chunks/initial frames from interleaving. Outbox delivery errors retain retries; a 30-second active-connection reconciliation repairs missed notifications. Session authorization is rechecked on messages and before snapshot pushes. Clients ping around every 30 seconds; a connection with no client message for 60 seconds expires. Sync HTTP worker threads submit async services to the backend lifespan loop that owns its DB pool/NATS connection.

REST remains for authentication, management, accept/discard, offline commands, full recovery snapshots and widget summaries. There is no promised perpetual background WebSocket on a mobile device. Opening/resuming the app should recover state; existing client polling remains fallback pending later app validation.

Widget UI contains only “Có X giao dịch cần phân loại” or “Không có giao dịch cần phân loại”, and taps open Biến động. APNs/FCM payloads contain only pending count/revision, never money/account/content. iOS WidgetKit and Android scheduling decide background execution; neither a five-minute refresh nor a 10–20-second background widget update is guaranteed. Push receiving, token registration and widget refresh on actual mobile devices remain unverified in this session.

## 5. API map

All financial/admin access is authenticated and checked server-side. This is the practical endpoint map; API request models in source are authoritative.

| Purpose | Endpoints |
|---|---|
| Health | `GET /v1/health/live`, `GET /v1/health/ready` |
| Identity | `/v1/auth/register`, `/login`, `/renew`, `/logout`, `/change-password`; `GET /v1/me` |
| Collector | `GET /v1/collector/registry`, `POST /v1/collector/events`, `POST /v1/collector/heartbeat` |
| Bank links | `GET /v1/banks`, `GET/POST /v1/bank-bindings`, `PATCH /v1/bank-bindings/{id}` |
| Pending inbox | `GET /v1/pending-events`; `POST /v1/pending-events/{id}/accept` or `/discard` |
| Sync | `GET /v1/sync/snapshot`, `POST /v1/sync/operations` |
| Realtime | WebSocket `/v1/realtime` |
| Ledger/catalog | `/v1/transactions`, `/v1/reports/period`, `/v1/categories`, category tag endpoints |
| Widget | `/v1/widget-token`, `GET /v1/widget/summary` (returns count, pending IDs and capture timestamp) |
| Push | `POST /v1/push/register`, `DELETE /v1/push/revoke` |
| Admin | `/v1/admin/users`, user `/approve`, `/capture`, `/temporary-password`, soft delete, `/restore`, `/purge`; bank configuration |

## 6. Configuration

`qlt/config.py` loads the repository root `.env`, then `backend/.env`; the backend file overrides the root file, and process environment variables override both. Keep real keys/passwords in private local files, not this document or mobile builds. The backend uses the PostgreSQL DSN, not Supabase Auth. Supabase API/service-role keys do not replace `DATABASE_URL`. Mobile configuration contains only the public HTTPS `API_BASE_URL` and its own session tokens.

| Variable | Default / purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL DSN; use the intended Supabase server connection with TLS, or isolated local test DB |
| `DATABASE_SCHEMA` | `qlt`; SQL migrations target this schema |
| `DEDUP_KEY` | 32-byte hexadecimal HMAC key; generate a private production value and keep stable/backed up |
| `ENVIRONMENT` | `development`, `test` or `production`; determines stream/subject names |
| `HOST`, `PORT` | Defaults `0.0.0.0`, `8000`; uvicorn command/service flags determine actual bind |
| `NATS_URL` | Native `nats://127.0.0.1:4222`; Compose backend uses `nats://nats:4222` |
| `NATS_USER`, `NATS_PASSWORD` | Broker auth; example user `qlt_backend`, private password required |
| `NATS_CREDENTIALS_FILE` | Optional NATS credentials alternative to user/password |
| `NATS_STREAM_PREFIX` | `QLT`; final name also includes environment and `_PENDING_V1` |
| `NATS_STORAGE_TYPE` | `file` in production; `memory` only for the normal isolated test stream |
| `NATS_MAX_BYTES`, `NATS_MAX_MSG_SIZE` | 1 GiB stream cap; 64 KiB per event |
| `NATS_DUPLICATE_WINDOW_SECONDS` | 86400; SQL fingerprints provide longer suppression |
| `NATS_PUBLISH_TIMEOUT_SECONDS` | 3; bounds broker requests |
| `NATS_RECONNECT_TIME_WAIT_SECONDS`, `NATS_MAX_RECONNECT_ATTEMPTS` | 1 second, 60 attempts |
| `OUTBOX_WORKER_POLL_INTERVAL_SECONDS`, `OUTBOX_WORKER_BATCH_SIZE`, `OUTBOX_WORKER_LEASE_SECONDS` | 1 second, 50 jobs, 30-second lease |
| `REALTIME_CHUNK_THRESHOLD_BYTES` | 262144 |
| `SESSION_LIFETIME_DAYS`, `WIDGET_TOKEN_LIFETIME_DAYS` | 30, 90 |
| `APNS_ENABLED` | false until configured |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`, `APNS_PRIVATE_KEY_FILE` | Apple token-auth credentials/topic and path to private `.p8` key |
| `FCM_ENABLED` | false until configured |
| `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_FILE` | Firebase project and private service-account JSON path |

Enabled push providers with missing configuration fail startup. APNs sends real HTTP/2 ES256-authenticated background requests; FCM uses OAuth and HTTP v1. Provider errors are retryable; known unregistered device tokens are removed. With both providers disabled, delivery is explicitly skipped, not simulated or claimed successful. Provider request contracts are tested with mocked HTTP responses; actual Apple/Firebase delivery requires credentials and device validation.

Broker-only environment required by `deploy/nats/nats.conf`: `NATS_HOST`, `NATS_MONITOR_LISTEN`, `NATS_STORE_DIR`, `NATS_USER`, `NATS_PASSWORD`. Native defaults are supplied by the launchd template except its secret password. Monitoring has no authentication, so bind it to loopback. Compose binds broker/monitor ports to host loopback and uses container-local `/data/jetstream` backed by the named `nats_data` volume.

Stream policy is file storage, LimitsPolicy, no automatic age expiry, DiscardNew, one message per event subject and DiscardNewPerSubject. Capacity rejects new uploads for retry instead of evicting pending items. Broker fsync uses `sync_interval: always`. Incompatible storage/retention/expiry configuration is rejected; readiness checks the required stream policy, not only server connectivity. There is one broker node and no high availability.

PostgreSQL privileges matter: current backend service paths perform cross-user routing/administration, and this suite uses an isolated privileged test connection. Do not assume the `qlt_app` NOBYPASSRLS role works for every service path; validate the chosen server-side role with RLS policies before production. Never expose a privileged DSN to mobile apps.

## 7. Run on the Mac mini

These commands are operating instructions, not a claim that deployment on macOS has been tested here.

```bash
brew install uv nats-server
mkdir -p /Users/Shared/quanlytao/data/jetstream /Users/Shared/quanlytao/logs
mkdir -p "$HOME/Library/LaunchAgents"
# Place the checkout at /Users/Shared/quanlytao and configure its private .env.
cd /Users/Shared/quanlytao/backend
uv sync --frozen
uv run python -m qlt.migrate
uv run python -m qlt.bootstrap_admin admin
```

Use the bootstrap password prompt rather than command-line password arguments. The bootstrap tool creates/resets an administrator; keep public registration user-only. Configure recipient bank accounts/instructions and activate a collector through the existing setup/admin tooling.

The native broker template uses `uv run --frozen --no-dev python -m qlt.messaging.run_nats`. This entry point reads the same private `.env` as the backend, exports only the broker settings, and replaces itself with `nats-server`. It binds loopback and stores payloads at `/Users/Shared/quanlytao/data/jetstream`. Supply `NATS_USER` and `NATS_PASSWORD` once in the private `.env`; secrets are not embedded in the plist and do not depend on a transient `launchctl setenv` setting. NATS itself does not parse `.env`; the entry point handles that.

```bash
cd /Users/Shared/quanlytao
cp deploy/macos/app.quanlytao.nats.plist "$HOME/Library/LaunchAgents/"
cp deploy/macos/app.quanlytao.backend.plist "$HOME/Library/LaunchAgents/"
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/app.quanlytao.nats.plist"
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/app.quanlytao.backend.plist"
curl -f http://127.0.0.1:8000/v1/health/live
curl -f http://127.0.0.1:8000/v1/health/ready
curl -f http://127.0.0.1:8222/varz
curl -f http://127.0.0.1:8222/jsz
```

The Apple Silicon templates use `/opt/homebrew/bin/uv` and `/opt/homebrew/bin/nats-server`; confirm the installed paths before loading. Logs go to the checkout's `logs/` directory. LaunchAgents start for a logged-in user; always-on boot operation without login requires deliberate LaunchDaemon/credential configuration. Prevent the Mac from sleeping when acting as the server. Expose the backend through HTTPS/reverse proxy for remote phones; do not expose NATS or its monitoring port publicly.

For a manual backend process: `uv run uvicorn qlt.main:app --host 127.0.0.1 --port 8000`. Run a single worker initially. For containers, use `docker compose --env-file .env -f deploy/compose.yaml up -d --build` from the repository root. Provide both `NATS_USER` and `NATS_PASSWORD`; Compose requires the password and supplies internal broker settings. Native and Compose must not claim the same ports concurrently.

## 8. Backup, migration and recovery

Back up SQL identity/ledger/receipts/outbox metadata and the HMAC key together with broker data. A broker-only archive is not a complete application backup. Do not tar the live file store and call it a consistent snapshot: stop backend writes and NATS first, or use verified JetStream snapshot tooling with a coordinated database backup.

Native offline archive example after services are stopped:

```bash
mkdir -p /Users/Shared/quanlytao/backups
tar -czf /Users/Shared/quanlytao/backups/jetstream_$(date +%Y%m%d_%H%M%S).tar.gz \
  -C /Users/Shared/quanlytao data/jetstream
```

Restore while services are stopped. Preserve the current directory separately before unpacking; avoid unconditional `rm -rf` instructions. Restore/reconcile PostgreSQL metadata with matching broker content before resuming ingest. Terminal SQL receipts suppress resolved events even if an older broker backup contains their payloads; validate and clean those payloads during restore. An unmatched restored broker cannot reconstruct amounts from metadata-only receipts.

Legacy migration is a maintenance operation:

```bash
cd backend
uv run python -m qlt.messaging.migrate_pending --schema qlt --dry-run
uv run python -m qlt.messaging.migrate_pending --schema qlt --batch-size 50
```

Pause writes, apply SQL migrations and ensure the broker is initialized before dry-run. The dry-run reads existing stream metadata without updating its configuration. Live migration preserves event IDs/legacy rows, verifies/reuses already published payloads and conditionally commits publishing receipts. Confirm payload/hash/count parity before removing legacy payload rows. Never reset a cloud schema just because old personal data was not required.

There is **no `ENABLE_JETSTREAM=false` fallback**. Reverting code after new JetStream-only events have arrived requires reverse migration/reconciliation of remaining pending events and suppression of terminal records. An old SQL table is stale after cutover; merely restarting the old backend is not a safe rollback.

Watch readiness, stream bytes/capacity, publishing receipts older than a minute, pending cleanup jobs and failed notification jobs. Notification jobs reaching their retry limit need operator attention; cleanup continues retrying. Push/realtime are hints about authoritative state, not the source of truth.

## 9. Verification and remaining scope

Backend test infrastructure uses PostgreSQL at local port 5433 and a separate `QLT_TEST_TEST_PENDING_V1` stream on local NATS. Guards reject cloud/production DB DSNs and nonlocal test brokers. Provider flags are disabled in integration tests; provider contract tests mock external HTTP. The test client fixture propagates failures instead of swallowing exceptions.

```bash
docker compose -f deploy/compose.test.yaml up -d
cd backend
ENVIRONMENT=test DATABASE_URL='postgresql://test_user:test_password@127.0.0.1:5433/qlt_test?sslmode=disable' \
  uv run python -m qlt.migrate
uv run pytest tests -q
```

The isolated crash/persistence test requires a native `nats-server`; it uses private temporary ports, storage and test-only credentials, and skips explicitly if unavailable. Normal integration tests use the pinned NATS 2.10.20 container. The production config was also validated by that pinned server. The native crash test on this host uses NATS 2.14.6; neither is a macOS launchd test.

Current backend checks cover ingestion and duplicate ACKs, lost publish ACK recovery, terminal-state protection, simultaneous resolutions and same-operation retries, stale capture recovery, purge during broker outage and without a sequence, payload hash rejection, snapshot drift, WebSocket delivery of a newly ingested event, sync resolution/replay, outbox lease/retry behavior, provider request contracts and file persistence after abrupt broker death.

Latest backend run: `uv run pytest tests -q` — **54 passed**, no skipped tests, in 15.17 seconds. One upstream Starlette/httpx deprecation warning remains. Focused Ruff checks of the changed messaging/push/realtime modules and new tests passed. The backend Dockerfile builds successfully with the frozen lockfile. These checks used isolated local services and did not modify the Supabase cloud database. Migration 005 has been applied to the local test database; it still needs deployment to the intended server database.

Android USB tests, iOS Simulator tests (notch and Dynamic Island), actual APNs/FCM delivery, widget behavior, native bank-notification capture, UX/tap budgets and Mac mini deployment remain for later validation. Backend success is not evidence that those mobile/device checks passed.
