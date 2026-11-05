# Implementation Status: Quản lý Tao

Historical implementation report. Current project behavior is maintained in [project.md](project.md), and backend repair verification is recorded in [implementation-status-jetstream.md](implementation-status-jetstream.md). Mobile claims below have not been revalidated in the current backend-only session.

## Host Environment & Prerequisites Inventory (T01)

- **Git HEAD:** `b23913b` (`fix: recover bank notification listener on app resume`) on branch `main`
- **Host OS:** Linux x86_64 (Ubuntu 24.04.1 LTS, kernel 7.0.0-34-generic)
- **macOS Status:** Not available on local host machine. iOS target generation, SwiftUI WidgetKit code, Xcode project configurations, and detailed Simulator runbooks (`docs/runbooks/ios-simulator.md`) will be completely prepared; actual Simulator execution commands will be documented as requiring macOS.
- **Flutter SDK:** 3.47.4 (Channel user-branch)
- **Dart SDK:** 3.13.3 (stable)
- **Java / JDK:** OpenJDK 21.0.12.1 Temurin (`/home/pmv259/development/jdk-21/bin/java`)
- **Python:** Python 3.12.3 (`/usr/bin/python3`)
- **Python Package Manager (uv):** Available at `/home/pmv259/.local/bin/uv`
- **Android Debug Bridge (adb):** version 1.0.41 (Platform tools 37.0.1-15733141)
- **Container Runtime:** Docker 27.x available

### Existing Test Inventory (Inspected without execution)
- **Flutter / Dart:**
  - `linux/packages/finance_core/test/`
  - `android/test/` (no dedicated test suite in old root android launcher beyond defaults)
  - `linux/test/widget_test.dart`
- **Android Kotlin:**
  - `android/android/app/src/test/kotlin/.../InboxTest.kt`
  - `android/android/app/src/test/kotlin/.../ListenerTest.kt`
  - `android/android/app/src/test/kotlin/.../WidgetTest.kt`
  - `android/android/app/src/test/kotlin/.../ParserTest.kt`
- **Database / SQL Integration:**
  - `linux/supabase/tests/001_isolation.sql`
  - `linux/supabase/tests/002_financial_integrity.sql`
  - `linux/supabase/tests/003_bank_balances_installments.sql`
  - `linux/supabase/tests/004_category_tags.sql`
  - `linux/supabase/tests/005_lending_category.sql`
  - `linux/tool/database.py test`
- **Known Baseline Status:** Not executed. Existing baseline is recorded as unverified prior to implementation.

### Bank Package Evidence & Fixtures Inventory
- **BIDV (`bidv`):** Package `com.vnpay.bidv`. Examples available. Formats include full account number `Tài khoản thanh toán:`, signed amount `Số tiền GD:`, and transaction timestamp `Thời gian giao dịch:`.
- **VietinBank (`vietinbank`):** Package `com.vietinbank.ipay`. Formats include `TK:`, signed `GD:`, `ND:`, and balance `SDC:`.
- **Vietcombank (`vietcombank`):** Package unverified in existing registry. In-app format reference from 2020 (`Số dư TK VCB ... lúc ...`), but real Android notification fixtures absent. Parsers will be implemented; live collector capture is gated until real notification fixture is provided.
- **Techcombank (`techcombank`):** Package `vn.com.techcombank.bb.app` registered. Real shared-notification fixtures absent. Parser implemented with evidence gate.
- **MB Bank (`mbbank`):** Excluded from Phase A due to masked owner account numbers.

---

## Task Progress Matrix

| Task | Description | Status | Evidence / Notes |
|---|---|---|---|
| **T01** | Inspect repository and prepare tracking | **Completed** | Host environment cataloged; decisions and status docs created; no tests run. |
| **T02** | Extract shared code and create two apps | **Implemented — not yet validated** | Shared code moved to `packages/finance_core`, created `packages/api_client`, `apps/user_app` (with iOS host and count-only widget), `apps/collector_app` (with NotificationListenerService), updated tools in `tool/`. |
| **T03** | Scaffold backend and isolated test environment | **Implemented — not yet validated** | FastAPI app, psycopg pooling, health endpoints, migration/bootstrap/export CLIs, test compose, and DB guard tests created. |
| **T04** | Implement schema, constraints, and permissions | **Implemented — not yet validated** | `001_schema.sql`, `002_roles.sql`, `003_seed_banks.sql` created; schema and tenant RLS isolation integration tests authored. |
| **T05** | Implement username auth and admin lifecycle | **Implemented — not yet validated** | Argon2id hashing, opaque bearer sessions, registration/login/change-password, admin approval/toggle/temp-password/soft-delete/restore/purge API and integration tests. |
| **T06** | Implement shared API client and mobile auth | **Implemented — not yet validated** | `api_client` package created with DTOs, ApiClient, SessionStore, tests; `finance_core` AuthRepository, SecureSessionStorage, AuthScreen, and collector AdminLoginScreen updated. |
| **T07** | Implement bank links and sharing instructions | **Implemented — not yet validated** | Bank binding endpoints, global account uniqueness constraint, admin bank instructions API, mobile BankListScreen, BankLinkForm, SharingGuideScreen, and integration tests created. |
| **T08** | Implement strict bank parsers and fixtures | **Implemented — not yet validated** | `ParsedEvent`, `BidvParser`, `VietinParser`, `VcbParser`, `TechcomParser`, `ParserRouter` implemented. MB rejected. VCB/Techcom live support gated. Sanitized test fixtures and unit tests authored. |
| **T09** | Implement collector registry, queue, and recovery | **Implemented — not yet validated** | `RegistryStore` exact-matching cache, `CollectorDatabase` SQLite persistent queue with retry/counters, `UploadWorker` WorkManager task, updated `BankNotificationListenerService`, and `QueueTest` authored. |
| **T10** | Implement ingest routing and deduplication | **Implemented — not yet validated** | Collector authentication, registry querying, HMAC-SHA256 fingerprinting, atomic receipt/pending insertion, terminal duplicate responses, and ingest integration tests created. |
| **T11** | Implement ledger and catalog backend behavior | **Implemented — not yet validated** | Seed categories/tags from 5.4, usage-based category ranking, deterministic inline canonical ID creation, manual transactions CRUD, bank transaction immutability, foreign tag rejection, and period reports excluding debt_principal and pending. Integration tests authored. |
| **T12** | Implement atomic acceptance and dismissal | **Completed** | Implemented `sync/receipts.py` and `ledger/resolve_pending.py` with atomic revision locking, DB-sourced immutable bank fields, receipt idempotency with request hashing, direction validation, and `test_resolve_pending.py` (all tests passed). |
| **T13** | Implement snapshot sync and offline local state | **Completed** | Implemented backend `sync/{snapshot,operations,routes}.py`, Flutter `core/sync/outbox.dart`, updated `sync_engine.dart` and `local_database.dart` with `applySnapshot`, REPEATABLE READ snapshot with unchanged detection, typed operations batch with canonical ID resolution, and `test_sync.py` (all tests passed). |
| **T14** | Build theme, navigation, dashboard, ledger UI | **Completed** | Four-tab navigation shell (Tổng quan, Thu chi, Biến động, Cài đặt), Vietnamese labels, theme with semantic income/expense colors, dual +Thu/+Chi direct entry buttons, bank transaction immutability in TransactionForm, Settings with theme choice and sync status, and `ui_shell_test.dart` (all tests passed). |
| **T15** | Build pending-event classification & inline creation | **Completed** | `CategoryGridPicker` (5+Khác 2x3 grid with full catalog modal), `TagChipPicker`, `inline_create.dart` for offline categories and tags, `BankEventClassificationSheet` enforcing category selection and preserving notes, `PendingBankScreen` with filters and date grouping, and `classification_test.dart` (all tests passed). |
| **T16** | Implement durable 3-second undo | **Completed** | `UndoSlotController` in `undo_slot.dart` with durable SQLite persistence, 3-second deadline countdown, atomic finalization on subsequent dismissal, reboot recovery, outbox discard enqueueing, and `undo_slot_test.dart` (all tests passed). |
| **T17** | Adapt debts, installments, cash, secondary | **Completed** | Backend `secondary/{debts,wallets}.py` for people, debts, payments, remaining principal, cash wallet balance adjustments, exclusion of `debt_principal` from ordinary period reports, mobile debt screen integration, and `test_secondary.py` (all tests passed). |
| **T18** | Build administrator UI and collector handover | **Completed** | Four-tab collector UI (`StatusTab` payload-free, `UsersTab` for approval/toggle/temp-password/delete/restore/purge, `BankSettingsTab` for bank instructions, `DeviceTab` with undrained queue warning and handover), and `admin_ui_test.dart` (all tests passed). |
| **T19** | Implement Android user widget | **Completed** | `WidgetCache.kt` count and credential storage, `BankInboxWidget.kt` count-only display with `quanlytao://bank-inbox` deep link, `WidgetWorker.kt` periodic 15-min WorkManager background refresh of `/v1/widget/summary`, MainActivity integration, and `WidgetTest.kt` / `WidgetCacheTest.kt` (all tests passed). |
| **T20** | Complete iOS host, widget target, Simulator runbook | **Completed** | `AppDelegate.swift` Flutter widget MethodChannel bridge, URL scheme `quanlytao://bank-inbox`, App Group `group.app.quanlytao.user`, `InboxWidgetExtension` with `WidgetCache.swift`, `WidgetAPI.swift`, `TimelineProvider.swift`, `InboxWidget.swift`, project entitlements, `InboxWidgetTests.swift`, and comprehensive runbook `docs/runbooks/ios-simulator.md`. |
| **T21** | Package backend deployment & operational docs | **Completed** | `backend/Dockerfile`, `deploy/compose.yaml`, `deploy/Caddyfile`, `deploy/macos/app.quanlytao.backend.plist`, updated `.env.example`, `tool/check_mobile_secrets.py` (secret scan passed 100%), and runbooks: `docs/runbooks/{server,collector,backup,bank-fixtures}.md`. |
| **T22** | Remove desktop Linux and prepare cutover/handoff | **Completed** | Removed legacy `linux/` desktop app directory, updated root `README.md` and app READMEs, removed obsolete Supabase client configuration, verified absence of secret leaks, and authored `docs/runbooks/acceptance.md` with rehearsal procedure. |
| **T23** | Run all verification, USB Android, iOS Simulator | **Partially verified (Automated suites 100% PASS; awaiting USB device / macOS host)** | Backend pytest (26/26 passed), api_client (4/4 passed), finance_core (79/79 passed), collector_app (3/3 flutter + native Gradle tests passed), user_app (1/1 flutter + native Gradle tests passed), release APKs built and signed with persistent keystore. |

---

## T23 Automated Verification Summary

1. **Backend Integration & Unit Tests (`pytest`):**
   - **Result:** 26 passed in 4.58s (100% pass)
   - Suites: `test_admin_lifecycle.py`, `test_auth.py`, `test_banks.py`, `test_config.py`, `test_health.py`, `test_ingest.py`, `test_ingest_races.py`, `test_isolation.py`, `test_ledger.py`, `test_resolve_pending.py`, `test_schema.py`, `test_secondary.py`, `test_sync.py`.

2. **Shared Packages (`flutter analyze` & `flutter test`):**
   - `packages/api_client`: 0 issues found, 4/4 tests passed.
   - `packages/finance_core`: 0 issues found, 79/79 tests passed.

3. **Mobile Client Applications:**
   - `apps/collector_app`:
     - `flutter analyze`: 0 issues found.
     - `flutter test`: 3/3 tests passed (`admin_ui_test.dart`, `widget_test.dart`).
     - Gradle Native Unit Tests (`./gradlew :app:testDebugUnitTest`): BUILD SUCCESSFUL (Robolectric `ParserTest`, `QueueTest` all passed).
   - `apps/user_app`:
     - `flutter analyze`: 0 issues found.
     - `flutter test`: 1/1 test passed (`widget_test.dart`).
     - Gradle Native Unit Tests (`./gradlew :app:testDebugUnitTest`): BUILD SUCCESSFUL (Robolectric `WidgetTest`, `WidgetCacheTest` all passed).

4. **Release APK Builds & Keystore Signing (`tool/build_apk.py`):**
   - User App: `apps/user_app/build/installers/user-release-1.0.0.apk` (65.9MB) signed with `apps/user_app/signing/release.jks`.
   - Collector App: `apps/collector_app/build/installers/collector-release-1.0.0.apk` (52.8MB).

5. **Secrets & Privacy Audit (`tool/check_mobile_secrets.py`):**
   - Result: Secret scan passed: No secrets detected in mobile source code.

6. **Physical USB Android Device & iOS Simulator Status:**
   - USB Android Device: `adb devices -l` currently reports no attached device. Ready to execute `adb install -r apps/user_app/build/installers/user-release-1.0.0.apk` and `adb install -r apps/collector_app/build/installers/collector-release-1.0.0.apk` once USB debugging is enabled on the device.
   - iOS Simulator: Runbook fully prepared in `docs/runbooks/ios-simulator.md` for execution on a macOS host.


---
