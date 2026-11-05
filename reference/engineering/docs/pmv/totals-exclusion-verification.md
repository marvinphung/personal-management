# Historical: totals exclusion and editing — 1.1.2+4

Superseded by 1.1.3: exclusion removed; see debt-dates-verification.md.

- Per-debt switch applies to principal and all repayments, past/future. Per-investment-transaction switch applies to that entry.
- Default off; existing data retained. Excluded items remain visible in history and specialist balances/summaries.
- Debt detail has Chỉnh sửa; update principal/person/note/due/account/policy atomically with its ledger links. Payments and manual completion state are retained. Captured bank source values remain read-only.
- Investment screen creates entries and opens the transaction editor for updates. Both bank classification paths expose the policy for new debts/investments; repayments inherit the selected debt policy.
- 101 shared tests passed, including device-sized create/edit widget flows for both features, both debt directions and past/future payment propagation. Seven isolated SQL/RLS suites passed, including RPC policy round trips and linked amount edits.
- Migration 009 applied to cloud without resetting or removing the existing two loans.

## A54 verification

- Installed final signed release 1.1.2+4 via ADB.
- Edited existing Nguyên Minh debt: excluded it, verified both debt and linked transaction flags in cloud, then restored its original included setting. Monthly expense/chart changed from 2,245,000 to 1,245,000 and back; outstanding loans remained 2,200,000 throughout. Principal values remain chó tiến 1,200,000 and Nguyên Minh 1,000,000.
- Created a clearly named test investment via the investment screen for 4,321 VND with exclusion enabled; it remained in the investment summary/history. Opened it through detail → Sửa, changed amount to 1,234 and turned exclusion off. Cloud confirmed new exact amount and policy. Deleted only that synthetic entry via the app and confirmed its cloud tombstone and empty active investment history.
- Temporary policy testing restored original settings. No reset, no existing principal or payment history removed.
- Evidence: `artifacts/pmv-totals-exclusion-2026-11-02/`.
