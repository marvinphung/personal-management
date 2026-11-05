# Debt dates and always-count totals — 1.1.3+5

Supersedes the per-item exclusion option in 1.1.2. All income/expense movements, including debts and investments, always count in totals and charts. All exclusion controls/badges have been removed. Legacy flags are ignored locally; migration 010 clears cloud flags and forces old/outbox writes false while retaining compatibility columns. No reset.

Manual debt create/edit now has Ngày giao dịch, default today. Hạn trả remains a separate optional field. Selected loan date is saved atomically to debts.started_at and linked transactions.occurred_at, so a remembered cash loan can be recorded for yesterday or an earlier month. created_at remains the actual entry timestamp. Repayment forms likewise expose Ngày thu/trả nợ and persist matching payment/ledger dates. Captured bank source dates remain read-only.

Verification: 101 shared tests pass, static analysis clean, seven isolated SQL suites pass. Tests cover both debt directions, backdated create/edit/repay, monthly attribution, preserving payments, bank date protection and real date-picker widget interaction. Cloud migration retains existing amounts, dates, IDs, links and statuses.

A54: versionName 1.1.3 / versionCode 5 installed successfully. Device date-picker verification is pending device unlock (PIN lock screen); no loan dates have been changed for this check.
