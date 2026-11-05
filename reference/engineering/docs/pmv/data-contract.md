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

### Full Tag Slug List

```
# Expense categories:
Ăn uống: ansang, antrua, antoi, ankhuya, anvat, caphe, nuocuong, douongkhac, dichoi, sieuthithucpham, datdoan, nhahang, nhau, tiec
Đi lại: xangxe, xeom, taxi, guixe, suaxe
Mua sắm: quanao, giaydep, phukien, docanha, dogiadung, dodientu, dodungcongviec
Nhà & hóa đơn: tiennha, tiendiennuoc, internet, dienthoai, phidichvu
Giải trí: xemphim, game, nghenhat, dangkydichvu, dichoi2, sukien
Sức khỏe: khambenh, thuoc, thethao, baohiem, thucpham
Gia đình & quà tặng: bietbome, hotronguoi, quatang, sinhnhat, damcuoi, damtang, letet
Du lịch: dichuyendulch, luutru, anuong, thamquan, muaqua, tour
Chi khác: phinganhang, phigiayto, tutthien, chuaphanloai
Trả sau: shopee, tiktok, thetindung, khac
Công nợ: chovay, tranno
Đầu tư (expense): chungkhoan, quyutu, crypto, vang, tiettkiem, gopvon, khac2

# Income categories:
Lương: luongchinh, phucap, lamthemgio
Thưởng: thuongthang, thuongquy, thuongtet, thuongduan, thuongkhac
Làm thêm: viecngoai, freelance, giasu
Được tặng: giacdinh, banbe, nguoiyeu, mungtuoi, quabangtiien
Thu khác: hoantien, laisuat, bandocanhan, khac3
Công nợ (income): thuno, vayno
Đầu tư (income): chungkhoan2, quyutu2, crypto2, vang2, tiettkiem2, gopvon2, khac4
```

Tag IDs: `md5(userId || ':pmvtag:' || slug)::uuid` — stable.

## 5. Debt (Công Nợ) Contract

### Model

Công nợ uses existing `debts` and `debt_payments` tables. Two PMV-specific columns added in migration 007:
- `debt_action text CHECK(IN ('cho_vay','tra_no','thu_no','vay_no') OR NULL)`
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

Stored in SharedPreferences key `undo_slot` as JSON:
```json
{
  "owner": "<userId>",
  "draftId": "<bankDraftId>",
  "deadline": "<iso8601>"
}
```

Behavior:
- Widget badge = native count - (1 if slot active, else 0)
- On app resume: check slot, if owner matches and deadline not passed → show undo snackbar
- On slot expiry: call `bankDraftRepository.finish(draftId, confirmed: false)` then clear slot
- On new "Bỏ qua": finalize previous slot (fire finish) → open new slot
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
- Selected calendar IDs: `calendar_selected_ids` (JSON array of int IDs)
- Dart and Kotlin sides use same key for consistency

### Widget Intent
- Each day cell: `PendingIntent.getActivity` with URI `/calendar?date=YYYY-MM-DD`
- Request code: `widgetId * 1000 + dayIndex` to avoid PendingIntent collision
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
- Bank source (direction, amount, time, original description): read-only in classify form
- User classifies: category (required), tags (optional for normal, required action tag for Công nợ), note (optional)
- Undo on "Bỏ qua": 3-second persistent slot (see §8)
- No bank balance display anywhere in UI

## 12. Files NOT to Modify

- `linux/supabase/migrations/001_finance.sql` through `006_lending_category.sql` — append only
- `android/android/app/src/main/kotlin/.../banknotification/` — only extend, don't break
- Main branch (v2) — do not touch
- `.env` files / credentials — do not copy or log
