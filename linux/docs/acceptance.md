# Acceptance verification

## Automated evidence

- Shared Flutter package: 38 passing tests and clean static analysis covering domain calculations, exact parsing, real SQLite repositories,
  filesystem persistence, pending operations, sync retry/conflict/tombstone behavior,
  local relational search and form/dashboard widgets.
- Both platform launch projects: clean static analysis and passing configuration-screen widget tests.
- Final Android ARM64 debug APK and Linux release bundle built successfully; apksigner verifies its signature and aapt
  verifies its package identity, label, minimum/target SDK and internet permission.
- Supabase SQL tests run under two authenticated identities within a rollback-only
  transaction: owner isolation, forbidden direct writes, RPC ownership checks,
  composite foreign keys, atomic debt/ledger mutations, repayment limits, idempotency,
  RLS flags/policies, secure view semantics and default category uniqueness.
- Linux native release build and a 10-second process startup check. The process
  remained alive until timeout. It had no public client configuration, so this
  verifies startup/configuration handling, not authenticated production workflows.

## Device acceptance checklist (requires configured public client settings)

Use two disposable accounts in a test Supabase project and do not enter real
financial information until this checklist passes on your devices.

- [ ] Android sign-up/email confirmation/sign-in; close/reopen to restore session.
- [ ] Create MB Bank and expense 45,000 / Coffee / Food / #coffee; view immediately.
- [ ] Linux signs in as the same account and receives the expense after sync.
- [ ] Disconnect Android; create 72,000 / Grab / Transport; force-close/reopen,
      reconnect and verify exactly one copy arrives on Linux.
- [ ] Linux creates #university; Android receives it after sync.
- [ ] Create Nam, lend 1,000,000 and repay 300,000; verify remaining 700,000 and
      cash balance changes on both devices while income/spending exclude principal.
- [ ] Transfer 2,000,000 between MB Bank and Savings; verify both balances and
      unchanged income/expense totals.
- [ ] Concurrent offline edits select a deterministic winner and display a conflict notice.
- [ ] Soft-delete on one device; reconnect the other and verify disappearance.
- [ ] Sign out with unsynced operations; verify warning and removal of private cache.
- [ ] Sign in as another account and verify no prior-user data appears.
- [ ] Craft User B Data API reads against User A's known UUIDs: no records returned.
      Craft finance_apply ownership/foreign-ID mutations: rejected, no modifications.
- [ ] Test Android keyboard, rotation and small screens; Linux resize/shortcuts,
      keyring session persistence, X11/Wayland and packaged bundle dependencies.

Public SUPABASE_URL/SUPABASE_ANON_KEY were absent during initial implementation.
No real Auth sessions or physical Android device were available for these checks.
