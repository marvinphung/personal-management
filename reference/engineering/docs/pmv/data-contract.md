# Quản lý PMV — Data Contract

## 1. Architecture Summary

- **App**: Flutter/Dart, Riverpod, go_router, Drift/SQLite, Supabase Auth/PostgreSQL
- **Android native**: Kotlin, Room, RemoteViews, Calendar Provider, NotificationListenerService
- **Sync**: offline-first outbox (SQLite → Supabase via sync_engine)
- **No FastAPI/JetStream/collector**: all bank capture runs natively on A54 directly

## 2. Namespace & Package

| Item | Value |
|------|-------|
| Android package ID | `app.personalfinance.finance_android` |
| App display label | `Quản lý PMV` |
| Supabase project | existing v1 project (not v2) |
| SQLite DB file | `finance.sqlite` in application support dir |
| Branch | `feature/quan-ly-pmv` |
| Base commit (v1) | `b23913bec723f7edfd3c61517556858e4385df61` |
| V2 UI reference | `f509cb0df06fe2e16d3e6c04d0461376725067c6` |

## 3. Category Schema

Categories have a `behavior` column (migration 006, extended in 007) that identifies their semantic role.

### Behavior Values (after migration 007)

| Value | Meaning | Direction |
|-------|---------|-----------|
| `normal` | Regular category | any |
| `lending` | Legacy lend-only (keep for backward compat) | expense |
| `cong_no_expense` | Công nợ — expense side | expense |
| `cong_no_income` | Công nợ — income side | income |
| `investment_expense` | Đầu tư — expense side | expense |
| `investment_income` | Đầu tư — income side | income |

### PMV Category List

**Expense:**
| Display name | Behavior | Stable ID seed |
|---|---|---|
| Ăn uống | normal | `pmvcat:expense:Ăn uống` |
| Đi lại | normal | `pmvcat:expense:Đi lại` |
| Mua sắm | normal | `pmvcat:expense:Mua sắm` |
| Nhà & hóa đơn | normal | `pmvcat:expense:Nhà & hóa đơn` |
| Giải trí | normal | `pmvcat:expense:Giải trí` |
| Sức khỏe | normal | `pmvcat:expense:Sức khỏe` |
| Gia đình & quà tặng | normal | `pmvcat:expense:Gia đình & quà tặng` |
| Du lịch | normal | `pmvcat:expense:Du lịch` |
| Chi khác | normal | `pmvcat:expense:Chi khác` |
| Trả sau | normal | `pmvcat:expense:Trả sau` |
| Công nợ | cong_no_expense | `pmvcat:expense:Công nợ` |
| Đầu tư | investment_expense | `pmvcat:expense:Đầu tư` |

**Income:**
| Display name | Behavior | Stable ID seed |
|---|---|---|
| Lương | normal | `pmvcat:income:Lương` |
| Thưởng | normal | `pmvcat:income:Thưởng` |
| Làm thêm | normal | `pmvcat:income:Làm thêm` |
| Được tặng | normal | `pmvcat:income:Được tặng` |
| Thu khác | normal | `pmvcat:income:Thu khác` |
| Công nợ | cong_no_income | `pmvcat:income:Công nợ` |
| Đầu tư | investment_income | `pmvcat:income:Đầu tư` |

Category IDs: `md5(userId || ':pmvcat:' || type || ':' || name)::uuid` — stable across seeds.

## 4. Tag Storage

Tags are stored as ASCII slugs (normalizeTagName / finance_tag_slug). Vietnamese labels are mapped
in Dart via `TagDisplay.labels` (slug → Vietnamese label). This is the single source of truth for display.

**CRITICAL**: Never compare tag behavior or business logic based on display labels. Use category `behavior` field or tag slug for logic.

### Action Tags (Công nợ — stable slugs)

| Slug | Display | Category direction | Debt action |
|------|---------|-------------------|-------------|
| `chovay` | Cho vay | expense (cong_no_expense) | cho_vay |
| `tranno` | Trả nợ | expense (cong_no_expense) | tra_no |
| `thuno` | Thu nợ | income (cong_no_income) | thu_no |
| `vayno` | Vay nợ | income (cong_no_income) | vay_no |

### Canonical seed

The migration `007_pmv_catalog_debt.sql` is authoritative for stored slugs; `TagDisplay.labels` maps these to the exact Vietnamese labels approved in the plan. Income/expense investment tags have different IDs but are grouped into a single display kind in `InvestmentSummary.filter`. Do not use the earlier draft slug list (it contained typos).

## 5. Debt (Công Nợ) Contract

### Model

Công nợ uses existing `debts` and `debt_payments` tables. Two PMV-specific columns added in migration 007:
- Action is derived from the direction/purpose and stable selected action tag; no debt_action column is used.
- `manual_completed_at timestamptz` — set when user manually completes

### Four Actions → Atomics

| Action | Category | Debt direction | Transaction type | Purpose |
|--------|---------|----------------|-----------------|---------|
| Cho vay (lend) | Công nợ expense | lent | expense | debt_disbursement |
| Trả nợ (repay borrowed) | Công nợ expense | borrowed | expense | debt_repayment |
| Thu nợ (collect lent) | Công nợ income | lent | income | debt_repayment |
| Vay nợ (borrow) | Công nợ income | borrowed | income | debt_disbursement |

Each action saves in ONE atomic batch: [transaction, debt/payment, tag links] — never two separate saves.

### Idempotency

- Debt ID for Cho vay/Vay nợ: `UUID.v5('finance:lending:${transaction.id}')` — stable
- Payment ID: `UUID.v5('finance:payment:${transaction.id}')` — stable
- importKey for bank drafts prevents duplicate on retry

### Overpayment

Validation that payment ≤ remaining amount is REMOVED. Negative remaining balance is allowed. No auto-completion.

### Status

| Status | Set by | Meaning |
|--------|--------|---------|
| `active` | default | in progress |
| `paid` | auto (calculated) | legacy; may not be used in PMV |
| `cancelled` | user | cancelled |
| `completed` | user (manual) | manually marked done; keeps history |

Completed debts:
- Shown in "Đã hoàn tất" section of debt screen
- Hidden from picker when choosing a debt to pay/collect
- No auto-transaction created when completing

## 6. Ledger / Monthly Totals

### `Ledger.monthly()` — PMV behavior

Include in totals:
- All non-deleted transactions for the month
- Transactions of any `purpose` (normal, debt_disbursement, debt_repayment)
- Đầu tư and Công nợ categories included

Exclude from totals:
- `type == 'transfer'` transactions (internal moves)
- `isScheduled(t)` = true (future installments, `installment_group != null && occurred_at > now`)
- Deleted rows

This means debt and investment cash flows count once toward income/expense totals.

## 7. Four-Tab Navigation Shell

| Index | Tab | Route | Icon | Semantic label |
|-------|-----|-------|------|----------------|
| 0 | Tổng quan | `/` | `Icons.home_outlined` | Tổng quan |
| 1 | Thu chi | `/transactions` | `Icons.receipt_long_outlined` | Thu chi |
| 2 | Biến động | `/transactions/pending` | `Icons.notifications_active_outlined` | Biến động |
| 3 | Cài đặt | `/settings` | `Icons.settings_outlined` | Cài đặt |

- Icon-only (no visible label text)
- Badge on tab 2 shows pending bank draft count (minus undo slot if active)
- Settings contains: Công nợ, Đầu tư, Lịch, Ghi chú, Danh mục, Tags, Ngân hàng, Giao diện, Ngôn ngữ, Đồng bộ, Đăng xuất

## 8. Undo Slot Contract

Stored in SharedPreferences key `undo_slot` as `owner|draftId|deadlineEpochMs`. Equivalent fields:
```json
{
  "owner": "<userId>",
  "draftId": "<bankDraftId>",
  "deadline": "<epoch milliseconds>"
}
```

Behavior:
- Widget badge = native count - (1 while a durable slot exists, including finish retry, else 0)
- On app resume: check slot, if owner matches and deadline not passed → show undo snackbar
- On slot expiry: call `bankDraftRepository.finish(draftId, confirmed: false)` then clear slot only after native success
- On new "Bỏ qua": await successful finalize of previous slot → open new slot
- On logout/owner change: clear slot, do NOT finalize (old owner's draft stays in native)
- Undo pressed: clear slot, refresh draft list (item reappears)

## 9. Calendar Contract

### Source
- Android Calendar Provider (Instances table for recurrence)
- Account: `minhvu2592005@gmail.com`, type: `com.google`
- Read-only: `READ_CALENDAR` permission only

### Querying
- Use `CalendarContract.Instances` not `CalendarContract.Events` to handle recurrence
- Query window: current month ± 1 month buffer for widget
- Dedup by `(eventId, begin)` to avoid multi-day event per-day duplicates within a single day

### Shading Thresholds
| Event count | Shading |
|-------------|---------|
| 0 | normal background |
| 1–2 | color.withOpacity(0.2) |
| 3–5 | color.withOpacity(0.5) |
| 6+ | color.withOpacity(0.8) |

Today marker: always shown regardless of event count (ring/circle overlay).

### SharedPreferences Key
- Selected calendar IDs: native preferences `pmv_calendar`, key `selected` (JSON array of IDs). Explicit empty remains empty. Dart uses MethodChannel loadSelectedIds/saveSelectedIds.
- App and widget both use CalendarData.selected; defaults require visible AND sync_events.

### Widget Intent
- Each day cell sends ACTION_SELECT_DAY to update that widget; title/event opens `/calendar?date=YYYY-MM-DD`.
- Unique intent data URI includes widget ID and date; title/event uses widget ID request code.
- Deep link consumed once (handled in MainActivity.onNewIntent → router.go)

## 10. Widget Specs

### Biến Động 2×2
- Count: pending bank drafts (minus undo slot)
- Label: "Biến động" (always Vietnamese)
- Tap: opens app at `/transactions/pending` tab
- No amount/balance shown
- Refresh: on update period + on native inbox change event

### Lịch 4×2
- Left: mini month grid (7 cols × 6 rows max), Mon start
- Right: selected day + event list
- Default selected: today
- No lunar dates, no + button
- Background: dark translucent `#B0202020` with radius 24dp
- Tap day: PendingIntent to open `/calendar?date=YYYY-MM-DD`
- Tap header: PendingIntent to open `/calendar`
- No permission: show "Cần quyền đọc lịch"

## 11. Bank Import Contract

- Native capture: v1 MB/VietinBank/BIDV/Techcombank parsers untouched
- Channel: `personal_finance/bank_inbox` (unchanged)
- Bank source (direction, amount, currency, time, original description) is read-only in classify AND later edits. Normalized bank_source provenance is persisted with the transaction and enforced by the repository and a PostgreSQL update trigger. No raw notification text is uploaded.
- User classifies: category (required), tags (optional for normal, required action tag for Công nợ), note (optional)
- Undo on "Bỏ qua": 3-second persistent slot (see §8)
- No bank balance display anywhere in UI

## 12. Files NOT to Modify

- `linux/supabase/migrations/001_finance.sql` through `006_lending_category.sql` — append only
- `android/android/app/src/main/kotlin/.../banknotification/` — only extend, don't break
- Main branch (v2) — do not touch
- `.env` files / credentials — do not copy or log

## Historical: per-item totals exclusion (superseded by 1.1.3)

`debts.exclude_from_totals` and `transactions.exclude_from_totals` default to false. Missing/NULL from legacy outbox payloads means false. Debt policy is copied to its principal and all past/future repayment transactions in the same local outbox batch when edited. Each investment transaction has its own policy. It affects general monthly totals, net/saving rate, daily chart and category/tag breakdown only; records, real account balances, debt balances and investment-specific summaries retain the full amounts.

Debt details now offer Chỉnh sửa for person, principal amount, due date, note, optional account and totals policy. Existing debt/payment IDs and manual completion state remain intact. Direction cannot change after a repayment; captured bank amount/type/account remain read-only. Investment history opens the existing transaction detail/editor; its screen also has a create action.

## Current: always-count totals and debt dates (migration 010, release 1.1.3)

The exclusion feature is removed at the user's request. All debt/investment income and expenses count in monthly totals, net/saving rate and charts. Legacy exclude_from_totals values are ignored by clients and forced false on database writes; columns remain only for durable payload compatibility.

Manual loan dates are selectable on creation and editing; debts.started_at equals its linked transactions.occurred_at. Manual repayment dates likewise match debt_payments.paid_at and the linked ledger date. The real creation timestamp is unchanged. Due date is separate/optional. Source bank dates remain immutable.

## Shared purchases and bill repayments (migration 011, release 1.1.4)

Every expense category has a distinct Mua chung tag. Income category Nhận share bill contains tags mirroring active expense category names. Optional tags.display_name provides readable labels; normalized globally unique names and stable IDs remain the storage keys. Shared markers do not replace mandatory debt actions. General income/expense totals include these records normally. See shared-bills-verification.md for current validation.
