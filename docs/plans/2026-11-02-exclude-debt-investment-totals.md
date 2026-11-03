# Per-item totals exclusion and editing

Approved scope: a switch while creating debt/investment, editable later from the respective section. Default off preserves existing totals. Excluded records remain in history and specialist balances.

1. Store `exclude_from_totals` on debts and transactions; debt policy applies to the principal and every past/future repayment. Investment policy belongs to each investment transaction.
2. Central totals predicate filters monthly income/expense, daily chart and category/tag breakdown; actual account balances, debt balances and investment summary remain unchanged.
3. Add create/edit switches to all relevant entry paths (including bank classification). Add debt edit action with atomic principal+ledger updates, retaining payments/status. Bank source values remain immutable.
4. Add investment creation from its own screen; use existing transaction editor for later updates.
5. Verify SQLite/outbox, migration/RPC round-trip, widget create/edit flows, then build/install and inspect A54. Preserve existing user records. No reset.
