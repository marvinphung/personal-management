# Money inputs and debt person picker (2026-11-02)

- All monetary editors group digits as typed (1000000 → 1,000,000; 4321 → 4,321), including opening balances, transactions and debt amounts. Parsing preserves integer minor units. Cursor, deletion, paste, selection and IME composition are covered.
- The person picker remains enabled with an empty catalog and offers inline creation. Newly saved people are selected immediately without clearing the outer amount.
- Debt creation and repayment accept no payment account. Such movements remain linked ledger transactions, included in totals, with account_id null. Migration 008 permits this for debt purposes only; ordinary transactions and transfers retain account requirements. No reset is needed.
- Release 1.1.1+3. Shared test suite: 95 passing; static analysis clean.
- On A54: 4321 rendered 4,321; 1200000 rendered 1,200,000. Created both requested loans through the app: chó tiến 1,200,000 VND and Nguyên Minh 1,000,000 VND. The second loan omitted the payment account. Read-only cloud verification confirmed exactly two loans, matching linked ledger amounts, and a null account for Nguyên Minh.

The per-item option is implemented in release 1.1.2; see totals-exclusion-verification.md.
