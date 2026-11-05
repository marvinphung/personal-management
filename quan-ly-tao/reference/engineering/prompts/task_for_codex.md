Work autonomously in this repository on my Mac mini M1 (8 GB RAM / 256 GB SSD).

Your task is to build, run, test, diagnose, and fix the backend and the iOS user app from a fresh verification baseline. Also act as a senior mobile UI/UX engineer: inspect the actual running interface and fix broken layouts, confusing interactions, unnecessary steps, and inconsistent states.

Do the work, not just prepare a plan.

AUTHORIZATION AND WORKING RULES

- I authorize routine repository edits, dependency installation, builds, local test databases, local NATS instances, simulator creation/boot, test-data seeding, screenshots, and restarting processes created for this task.
- Do not ask me to reconfirm requirements or approve ordinary implementation choices. Read the project, choose sensible defaults, and continue.
- Use the tool permissions already granted to this session. A prompt cannot override sandbox, macOS security, administrator-password, or execution-approval requirements. Do not bypass those controls. If an action is blocked, record the exact blocker, continue independent work, and report it clearly.
- Preserve unrelated uncommitted changes. Do not reset the repository, delete unrelated simulators/data, uninstall unrelated software, or push commits.
- Read private .env files locally when needed. Never print their contents, credentials, database passwords, signing keys, or access tokens. Never embed backend secrets in the app.
- Test against isolated local services and synthetic accounts. Do not reset, purge, or migrate the production Supabase database as part of testing.
- Send concise progress updates during work. Ask a question only if a genuinely missing requirement prevents further safe progress; otherwise use the documented requirements.
- Do not stop after finding errors: fix them and rerun the relevant checks.
- Do not recreate the deleted implementation plans.

1. UNDERSTAND THE CURRENT PROJECT

Read AGENTS.md and docs/project.md first. The project reference is the maintained description of requirements, data flow, configuration, and operations.

If .codegraph/ exists, use CodeGraph before locating or reading code. Otherwise use normal repository search.

Inspect the current implementation and git status. Earlier backend verification reported 54 passing tests, but treat that only as historical evidence. Verify this checkout yourself.

Scope:
- FastAPI backend, PostgreSQL, NATS JetStream, realtime gateway, and push-provider backend contracts.
- Flutter iOS user app and its native WidgetKit extension.
- Actual iOS Simulator UI testing on both notch and Dynamic Island devices.
- Android device testing is deferred.

2. PREPARE THE MAC ENVIRONMENT

Discover installed versions and paths for:
- Xcode and command-line tools.
- Available iOS Simulator runtimes/devices.
- Flutter/Dart, CocoaPods, Python/uv, and nats-server.
- Docker or other available local PostgreSQL tooling.

Install missing ordinary dependencies using the available permissions. Prefer existing compatible versions and lockfiles. Do not upgrade the entire project without a concrete reason.

Respect the Mac's 8 GB RAM:
- Run heavy builds and simulator sessions sequentially when appropriate.
- Keep concurrency bounded.
- Stop temporary processes you created when no longer needed.

Create/use an isolated local PostgreSQL test database and a separate test NATS stream/storage directory. Apply all repository SQL migrations to that isolated database, including 005_receipt_fencing.sql and any newer migrations.

Use a separate runtime configuration for simulator testing. Ensure API URLs work from the Simulator. Do not accidentally point test clients at production.

3. BUILD AND VERIFY THE BACKEND

Install locked dependencies, run appropriate static checks, build the backend, and execute the entire backend test suite.

Use real local PostgreSQL and NATS for integration tests. Exercise the actual HTTP/WebSocket services, not only mocks.

Verify at least:
- Registration, admin approval, login, temporary-password flow, and authorization.
- Bank-binding uniqueness, preserved leading zeros, and account replacement.
- Collector routing by full owning bank account.
- Valid integer VND amounts and immutable bank fields.
- Duplicate ingestion and retry after a lost publish acknowledgment.
- Recovery after broker/backend interruption.
- Accepted/discarded events cannot return to pending.
- Simultaneous resolution from multiple clients creates no duplicate ledger entries.
- Replaying the same offline operation returns its original result.
- Capture/binding fencing after configuration changes.
- Snapshot revision consistency and payload identity/hash validation.
- New event delivery over the authenticated WebSocket.
- Reconnect and authoritative snapshot recovery.
- Cleanup retries, expired leases, and repeated deletion.
- Hard purge during a broker outage retains the deleted account and its reservations until broker cleanup succeeds.
- File-backed broker persistence after restart/crash.

Check the actual database role used by the server. Do not assume tests using a privileged PostgreSQL account prove that a NOBYPASSRLS runtime role works. If necessary, fix the intended tenant/service authorization paths and test them without broadly disabling RLS.

Verify push adapters honestly:
- Test APNs/FCM request construction, failures, disabled configuration, and token handling.
- Do not call mocked provider requests or simulated notifications real push delivery.
- Keep missing provider credentials from blocking unrelated backend and Simulator verification.

Keep the tested backend and broker running for the iOS end-to-end tests.

4. BUILD AND LAUNCH THE IOS APP

Inspect the existing Flutter iOS runner, native code, entitlements, App Groups, deep links, and WidgetKit target.

Resolve build/configuration problems and build for the iOS Simulator. Simulator builds should not require physical-device signing or a paid Apple account.

Select two installed device models:
- One with a notch, such as an iPhone 13.
- One with Dynamic Island, such as an iPhone 15 or another available model.

If necessary, create suitable Simulator devices using an installed runtime. Record the exact model, runtime, and simulator ID used.

Install and launch the actual app. Inspect runtime logs and fix crashes, blank screens, broken navigation, failed API connections, and native integration errors.

5. TEST THE ACTUAL UI AND USER FLOWS

Use available simulator automation, Flutter integration tests, XCTest, accessibility inspection, or other appropriate tools. Inspect screenshots of the running app yourself.

A successful build or launch is not sufficient.

On both device types, verify:
- Login, registration, pending approval, approval refresh, logout, and session expiration.
- Adding a bank account and viewing sharing instructions.
- Duplicate-account errors and account replacement.
- The Tổng quan, Thu chi, Biến động, and Cài đặt tabs.
- Empty, loading, error, offline, and populated states.

Generate clearly labeled synthetic bank events through the real collector/backend ingestion path. Do not insert fake inbox rows directly into the app database for end-to-end proof.

Supported banks are BIDV, VietinBank, Vietcombank, and Techcombank. MB is excluded. Do not present synthetic payloads as evidence that real bank notification parsing has been validated.

Verify the complete event flow:
collector submission → backend → JetStream/SQL metadata →
WebSocket → local app state → Biến động → classification →
ledger entry or discard → updated inbox/widget count.

Classification requirements:
- Display transaction time, signed amount, bank/account, and original bank content.
- Bank amount, direction, time, account, and original content are read-only.
- Category is required; tags and personal note are optional.
- Show five most-used categories immediately in a 2×3 grid, with “Khác…” as the sixth control.
- Rank income and expense categories separately.
- Support income tags as well as expense tags.
- Add categories/tags inline while preserving the classification draft.
- Common acceptance with one tag should take no more than five taps from the widget.
- Extended flows may take more, but remove unnecessary steps.

Discard requirements:
- Hide the item immediately.
- Show a bottom snackbar with transaction amount, Undo, and a three-second countdown.
- Discarding another event finalizes the previous discard and replaces the undo slot.
- Verify undo, expiry, navigation away, app restart, offline processing, and reconnect.
- A resolved event must not reappear after refresh or restart.
- Acceptance must create exactly one ledger entry.

Also exercise manual income/expense entry, reports, filters, and existing secondary features affected by your changes.

6. AUDIT AND FIX UI/UX

Review both notch and Dynamic Island layouts in:
- Light and dark themes.
- Normal and enlarged text sizes.
- Keyboard-open states.
- Long Vietnamese labels, long bank descriptions, large amounts, and long lists.

Check:
- Safe areas around the notch/Dynamic Island and home indicator.
- Header, tab bar, bottom sheet, snackbar, and keyboard overlap.
- Scrolling, focus, back navigation, and retained form state.
- Touch target sizes, contrast, readable Vietnamese text, and accessible labels.
- Visible progress/error feedback and duplicate-submit prevention.
- Consistent terminology, spacing, typography, and interaction behavior.

Fix concrete usability problems while preserving the documented product requirements. Do not introduce speculative features or a new visual design unrelated to the existing product.

Capture before/after screenshots for meaningful UI fixes.

7. VERIFY THE WIDGET

Build and test the actual WidgetKit extension on both simulator models.

Verify:
- App Group configuration and shared cache access.
- Count-only display:
  “Có X giao dịch cần phân loại”
  and “Không có giao dịch cần phân loại”.
- Tapping the widget opens Biến động.
- Counts reconcile after ingestion, acceptance, discard, undo, and app restart.
- The widget renders correctly at supported sizes.

Clearly distinguish:
- Shared-cache/widget rendering tests.
- Simulator-injected notifications.
- Actual APNs delivery.
- OS-scheduled background refresh.

Do not promise a guaranteed five-minute background refresh or infer physical-device delivery from Simulator success. Fix everything that can be verified locally and document the remaining device-dependent checks.

8. FINAL VERIFICATION AND DOCUMENTATION

After fixing issues:
- Rerun the complete backend suite.
- Run appropriate Flutter analysis/tests and iOS builds.
- Repeat affected end-to-end flows on BOTH notch and Dynamic Island simulators.
- Confirm no new runtime errors, navigation failures, or layout regressions.
- Verify documentation and configuration agree with the code.

Update docs/project.md with actual changes, configuration instructions, operating commands, and remaining limitations. Keep it the main project description.

Store screenshots and concise test evidence in a clearly named directory. Record commands, results, simulator models/runtimes, and any skipped or blocked checks. Never include secrets.

If native launchd configuration can be validated locally, verify its paths, environment loading, storage directories, and health endpoints. Use isolated test configuration for any service started during this task; do not silently switch the Mac to a production cloud database.

Finish with:
1. What you fixed.
2. Exact build/test results.
3. Evidence from both simulator device types.
4. Paths to screenshots and the updated project document.
5. How to start the tested backend and reopen the tested app.
6. Any genuinely blocked checks, with their exact reasons.

Do not claim “everything works” based only on passing unit tests. Continue until the authorized backend and Simulator work is complete, or a specific external requirement blocks the remaining portion.
