# Runbook: Acceptance Matrix & Verification Rehearsal

This runbook defines the complete end-to-end acceptance criteria, test execution sequence, and isolated rehearsal procedure for **T23**.

> [!IMPORTANT]
> **Zero Execution Rule during T01–T22:** Do NOT execute the commands in this runbook until T23. In T23, all automated test suites and device validations will be run systematically.

---

## 1. Required Acceptance Matrix

| # | Domain | Scenario / Verification Objective | Acceptance Criteria |
|---|---|---|---|
| **AC-01** | **User Lifecycle** | Registration with 3 fields (username, display name, password) | Rejects duplicate usernames; new account enters `pending` state; cannot access ledger/pending endpoints until approved. |
| **AC-02** | **Administration** | Admin approves pending user; default category seed | Approves user; provisions standard 5.4 default categories/tags; duplicate approvals do not duplicate seeds. |
| **AC-03** | **Temp Password** | Admin generates temporary password | Revokes all active sessions & widget tokens; user is forced to change password upon next login. |
| **AC-04** | **Tenant Isolation** | Multi-user boundary test | User A cannot query, resolve, or view User B's pending transactions, ledger entries, or custom tags. |
| **AC-05** | **Widget Token Scope** | Count-only credential security | Widget token can only access `/v1/widget/summary`; requests to `/v1/transactions` or `/v1/pending` return 401/403. No monetary figures returned. |
| **AC-06** | **Bank Parsers** | Exact VND & leading zero preservation | Extracts full account string (e.g., `0123456789`); preserves leading zeros; parses integer VND amounts without decimals. |
| **AC-07** | **Parser Fixtures** | BIDV 22:20 / 22:24 timestamp distinction | Two transactions with identical posting time but distinct minutes generate unique fingerprints and deduplicate independently. |
| **AC-08** | **Strict Rejection** | Non-financial & untrusted notifications | Parsers reject MB Bank notifications, promotional SMS, OTP verification codes, and failed transaction alerts. |
| **AC-09** | **Collector Invariant** | Single active collector device | Admin login on a second phone establishes a new collector session and increments epoch; uploads from the retired device are rejected with 409 conflict. |
| **AC-10** | **Classification Flow** | Mandatory category & bank field immutability | User must select a category before accepting; bank-originated fields (amount, occurred_at, bank_code, owner_account, description) cannot be altered. |
| **AC-11** | **Durable 3s Undo** | Pending item dismissal countdown | Dismissing an event starts a 3-second deadline stored in SQLite; tapping "Hoàn tác" restores it immediately; app kill/reboot after 3s finalizes dismissal. |
| **AC-12** | **Secondary Modules** | Debts, cash wallets & reports | `debt_principal` is excluded from monthly income/expense totals; debt payments track remaining principal; cash adjustments calculate running balance. |
| **AC-13** | **Offline Sync** | Snapshot consistency & outbox remapping | Offline changes queue in local SQLite outbox; upon reconnection, mutations apply in order, client temporary IDs are remapped to server UUIDs. |
| **AC-14** | **Android Widget** | Home screen count-only display | Shows pending count; shows `0` when cleared; tapping opens `quanlytao://bank-inbox` and navigates to `/pending`. Never displays money. |
| **AC-15** | **iOS Simulator** | Native Swift tests & widget layout | Swift unit tests pass; Small and Medium widgets render in light/dark mode; deep links navigate to `/pending`. |

---

## 2. Isolated Test Rehearsal Procedure (T23 Sequence)

In T23, execution proceeds in five sequential phases:

### Phase 1: Test Database & Backend Pytest Suite
```bash
# 1. Start dedicated test PostgreSQL container on port 5433
docker compose -f deploy/compose.test.yaml up -d

# 2. Run backend migrations on test database
DATABASE_URL="postgresql://test_user:test_password@localhost:5433/qlt_test" \
DATABASE_SCHEMA="qlt" \
ENVIRONMENT="test" \
uv --project backend run python src/qlt/migrate.py

# 3. Execute all integration and schema tests
DATABASE_URL="postgresql://test_user:test_password@localhost:5433/qlt_test" \
DATABASE_SCHEMA="qlt" \
ENVIRONMENT="test" \
uv --project backend run pytest backend/tests/ -v
```

### Phase 2: Flutter Packages & Mobile App Analysis
```bash
# Test packages/api_client
(cd packages/api_client && flutter pub get && flutter test)

# Test packages/finance_core
(cd packages/finance_core && flutter pub get && flutter analyze && flutter test)

# Test apps/user_app
(cd apps/user_app && flutter pub get && flutter analyze && flutter test)

# Test apps/collector_app
(cd apps/collector_app && flutter pub get && flutter analyze && flutter test)
```

### Phase 3: Android Native Kotlin Tests (Collector & User Widget)
```bash
# Collector parsers, Room, and NotificationListener tests
(cd apps/collector_app/android && ./gradlew testDebugUnitTest)

# User App WidgetCache unit tests
(cd apps/user_app/android && ./gradlew testDebugUnitTest)
```

### Phase 4: USB-Connected Android Device Verification
```bash
# 1. Verify physical USB connection
adb devices -l

# 2. Build release APKs with local signing key
python3 tool/build_apk.py user
python3 tool/build_apk.py collector

# 3. Install both APKs on the connected phone
adb install -r apps/user_app/build/installers/user-release-1.0.0.apk
adb install -r apps/collector_app/build/installers/collector-release-1.0.0.apk

# 4. Verify co-existence without package ID or provider collisions:
adb shell pm list packages | grep quanlytao
# Expected:
# package:app.quanlytao.user
# package:app.quanlytao.collector
```

### Phase 5: iOS Simulator & Widget Runbook Validation
Document results per `docs/runbooks/ios-simulator.md`.

---

## 3. Production Cutover & Schema Safeguards

When cutover to production occurs:
1. Target only the dedicated `qlt` schema:
   ```sql
   CREATE SCHEMA IF NOT EXISTS qlt;
   ```
2. **NEVER drop, truncate, or alter the `public` schema.**
3. Verify that `.env` contains production `DATABASE_URL` and unique `DEDUP_KEY`.
4. Run `tool/check_mobile_secrets.py` to ensure zero secret leakage in release APKs.
