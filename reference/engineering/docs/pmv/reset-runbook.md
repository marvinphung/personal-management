# Quản lý PMV — Reset & Cutover Runbook

This runbook guides Codex during Task 7 for executing the scoped v1 reset and cutover to Quản lý PMV on Samsung A54.

---

## 1. Safety Rules & Boundaries

- **Target Scope:** ONLY v1 tables in `public` schema (`accounts`, `categories`, `tags`, `people`, `transactions`, `transaction_tags`, `debts`, `debt_payments`, `notes`, `finance_operations`).
- **Forbidden:**
  - DO NOT touch or drop `auth.users`.
  - DO NOT touch any tables in `qlt.*` schema or other v2 structures.
  - DO NOT execute raw `DROP SCHEMA public` or `TRUNCATE` all tables.
  - DO NOT hardcode or guess the user UUID.

---

## 2. Prerequisites

1. Target User UUID obtained from Supabase Auth dashboard or authenticated session.
2. PostgreSQL connection variables configured in `linux/.env` or passed via environment:
   ```bash
   SUPABASE_DATABASE_URL=postgresql://...
   ```
3. Python environment with `psycopg` installed (`pip install "psycopg[binary]"`).

---

## 3. Step-by-Step Cutover Procedure

### Step 3.1: Stop Old Writers
On the Samsung A54 device:
- Close any running v1/v2 app instances.
- Ensure no background sync is actively writing to the Supabase endpoint.

### Step 3.2: Dry-Run Verification
Execute the dry-run command from the repository root:
```bash
python linux/tool/reset_pmv.py --user-id <USER_UUID>
```
Verify the output:
- Lists all allowlisted tables.
- Shows exact row count matching the target user.
- Verifies mode is `DRY-RUN` with zero rows actually modified.

### Step 3.3: Apply Migration 007
Run the database migration tool to apply `007_pmv_catalog_debt.sql`:
```bash
python linux/tool/database.py migrate
```
Verify that `007_pmv_catalog_debt.sql` is reported as `Applied`.

### Step 3.4: Scoped Reset & Seed Execution
Execute the live deletion and seed default PMV categories and tags:
```bash
python linux/tool/reset_pmv.py --user-id <USER_UUID> --execute --seed
```
Verify:
- All target table rows for `user_id` are deleted in reverse foreign-key order.
- `finance_pmv_defaults` runs and seeds all approved categories and tags.

### Step 3.5: Local Device Reset
On the Samsung A54 device:
- Clear app storage/cache:
  ```bash
  adb shell pm clear app.personalfinance.finance_android
  ```
- Install the newly built Quản lý PMV APK.

### Step 3.6: Launch & Verify
1. Open Quản lý PMV on A54.
2. Sign in with the user's Supabase credentials.
3. Verify initial sync:
   - 12 Expense categories seeded (Ăn uống, Đi lại, Mua sắm, Nhà & hóa đơn, Giải trí, Sức khỏe, Gia đình & quà tặng, Du lịch, Chi khác, Trả sau, Công nợ, Đầu tư).
   - 7 Income categories seeded (Lương, Thưởng, Làm thêm, Được tặng, Thu khác, Công nợ, Đầu tư).
   - All associated tags present.
   - Zero historical transactions/debts.
4. Verify notification listener permission prompt and Home Screen widgets (2×2 Biến động, 4×2 Lịch).
