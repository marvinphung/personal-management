# Debt dates and always-count totals

User supersedes the exclusion option: every income/expense movement, including debt and investment, always counts in general totals and charts. Remove all exclusion controls and badges. Ignore legacy local flags; migration 010 resets cloud flags and forces compatibility writes false without removing outbox-compatible columns.

Add Ngày giao dịch to manual loan creation/editing, default today; keep Hạn trả separate/optional. Save selected date into debts.started_at and linked transactions.occurred_at atomically. Repayment entry similarly selects Ngày thu/trả nợ and saves matching payment/transaction dates. created_at remains actual entry time. Preserve existing loan amounts, dates, status and payments. Bank-captured source date remains read-only.

Verify historical-month totals, both debt directions, editing dates without changing history, bank source protection, widget date-picker flow, SQL/RPC, and A54 before completion. Release 1.1.3+5. No database reset.
