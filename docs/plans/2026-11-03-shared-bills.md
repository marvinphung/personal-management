# Shared purchases and bill repayments

Approved: every expense category gets a Mua chung tag; income gets Nhận share bill with tags named after the expense categories. Ordinary income/expense accounting continues; this does not create debt balances.

Keep existing globally unique normalized tag names/IDs intact. Add optional display_name to tags for category-scoped shared labels, with canonical readable labels throughout editors, filters, history, dashboard and catalog. Seed distinct stable tag IDs for each source category. finance_defaults adds/refreshes the mapping, including user-created expense categories. Existing transactions/debts are untouched. Debt category action selection stays mandatory and Mua chung is an optional extra marker.

Verify tag selection and saved category/tag IDs in widget tests for ordinary expense, income share bill and debt expense. Verify seed idempotence and expense-to-income label mapping in isolated SQL. Apply schema/catalog to cloud, build 1.1.4+6 and verify A54 UI. Preserve prior debt date functionality and always-count totals.
