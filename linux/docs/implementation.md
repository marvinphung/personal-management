# Implementation checklist and decisions

- [x] Inspect repository and configuration names: empty platform directories; no CodeGraph index; .env untracked.
- [x] Inspect remote schema safely before applying additive migrations.
- [x] PostgreSQL schema, ownership foreign keys, RLS, constraints, triggers, atomic sync RPC.
- [x] Shared Flutter package + Android and Linux launch projects.
- [x] Supabase authentication and user-isolated local cache lifecycle.
- [x] Accounts, categories, tags, transactions and quick entry.
- [x] Monthly dashboard with local-calendar boundaries and debt exclusions.
- [x] People, debts, partial payments and atomic linked cash movements.
- [x] Notes, settings and local search.
- [x] Durable SQLite outbox, retry, deterministic conflicts and remote pull.
- [x] Adaptive mobile/desktop UX and keyboard shortcuts.
- [x] Domain, repository, widget and SQL isolation tests.
- [x] Analyze/test both launch projects; Linux release built and startup checked.
- [x] Android ARM64 debug APK produced and verified with apksigner/aapt.
- [x] Final Linux release rebuilt after opening-balance correction and startup checked.
- [x] Final Android and Linux native rebuilds include the tag-loading correction.
- [ ] Live authenticated two-device acceptance; public client configuration is missing.
- [x] README and limitations with actual verification evidence.

## Architecture decisions

Both launch projects depend on linux/packages/finance_core, a shared Flutter package.
No custom server. Supabase SDK calls Auth and PostgreSQL RPC/Data API directly.
All writes first commit domain rows plus an outbox operation in a single SQLite transaction.
A PostgreSQL RPC applies each operation atomically; linked debt/ledger changes share an operation.
UUID IDs and operation receipts make retry idempotent. Owner-composite foreign keys prevent
cross-user references even where an attacker knows another user's UUID.
Money is integer minor units in Dart/SQLite and numeric(20,0) minor units in PostgreSQL.
VND exponent is zero; currencies with fractional units retain an explicit exponent mapping.
Transfers require equal currencies until an exchange-rate model is introduced.
Debt cash movements use income/expense plus purpose, excluded from normal monthly analytics.
Updated_at is server maintained; a separate client_modified_at plus mutation UUID selects a
stable last-write winner. Device clock skew is an acknowledged limitation.
Remote pull uses a conservative full paginated reconciliation initially, avoiding timestamp
watermark gaps caused by transaction commit order; incremental acceleration can follow.
Budgets and recurring transactions are deferred until core acceptance scenarios are verified.


## Verification record (2026-09-13)

- Flutter 3.47.4 / Dart 3.13.3 installed under /tmp for this session.
- Existing Supabase public tables inspected before creating the finance schema.
- Migrations 001–003 applied without altering unrelated tables.
- SQL isolation and financial integrity suites passed again after restoring tooling;
  all fixture rows rolled back. Every domain table’s RLS flags/policies are asserted.
- Shared analysis clean; 38 tests passed, including negative saving-rate, opening-balance, delayed tag-loading and recent-tag regressions.
- Android: fresh flutter analyze clean; launcher widget test passed.
- Android APK signature verified (v2); package metadata confirms API 24 minimum,
  API 36 target, Personal Finance label and INTERNET permission.
- Linux: fresh flutter analyze clean; launcher widget test passed.
- Linux release compiled in a local Ubuntu 24.04 build container; native binary
  launched and remained alive for the 10-second startup check (timeout exit 124).
- Public client settings absent: authentication, real cloud-to-device synchronization,
  Android device interaction and platform session persistence remain unverified.
- APK ZIP integrity passed; no .env assets were included. Source and native
  artifact scans found no configured PostgreSQL password or database URL.
- Re-running the migration tool skipped all three existing versions without changes.
- No commits or remote Git pushes made. .env remains ignored and untracked.

Detailed manual acceptance steps: [acceptance.md](acceptance.md).


## Final artifacts

- Android ARM64 debug APK: `android/build/app/outputs/flutter-apk/app-debug.apk`.
  Final `flutter build apk --debug --target-platform android-arm64` exited 0.
  The rebuilt APK passed apksigner verification and ZIP integrity checks.
- Linux release bundle: `linux/build/linux/x64/release/bundle/`.
  Final `flutter build linux --release` exited 0.
- Final shared verification: `flutter analyze` clean, `flutter test` 38 passed.
- Final Android verification: analysis clean, one launcher widget test passed.
- Final Linux verification: analysis clean, one launcher widget test passed.
- Final source + Linux bundle + decompressed APK scan found no configured
  PostgreSQL password or database URL. No .env assets were packaged.
- Binaries are verification builds without public client settings. Add the two
  public values to root .env and rebuild via the documented allowlist launcher
  before attempting authenticated use.

## Language selection

English and Vietnamese are supported by the shared UI and Flutter Material localization delegates. The first authenticated session for an account on a device is gated by a language selection screen; subsequent sessions restore that account’s SharedPreferences choice. Settings can change it immediately, including offline. This non-sensitive device preference is retained on logout, separated by Supabase user ID, and is not synchronized to other devices. Missing or unsupported stored values require a new choice. Stored financial content and enum values are never translated.

Validation covers onboarding route gating, restoring preferences, account isolation, Settings updates without navigation loss, Vietnamese form layouts, and preserving ledger values when submitting a translated form.

Language change verification: shared analyze passed; 46 shared tests passed, including 8 localization tests. Android and Linux launcher analyze and one widget test each passed. Live authenticated onboarding on physical devices was not exercised for this change.
