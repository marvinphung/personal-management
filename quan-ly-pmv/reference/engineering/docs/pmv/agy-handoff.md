# Báo cáo bàn giao triển khai Quản lý PMV (Agy Handoff)

Tài liệu bàn giao triển khai source code app **Quản lý PMV** từ Agy cho Codex review, thực thi kiểm thử/build và nghiệm thu thiết bị (Task 7).

---

## 1. Thông tin môi trường & Mốc tham chiếu

- **Worktree triển khai:** `/home/pmv259/Documents/personal-projects/personal-management-pmv`
- **Branch:** `feature/quan-ly-pmv`
- **Base commit v1:** `b23913bec723f7edfd3c61517556858e4385df61` (branch `app-v1`)
- **Reference commit v2 (mẫu UI/luồng):** `f509cb0df06fe2e16d3e6c04d0461376725067c6` (branch `main`)
- **Thiết bị nghiệm thu:** Samsung Galaxy A54 5G (SM-A546E)
- **Tình trạng Git:** Source code trong worktree được để ở trạng thái **chưa commit** để Codex review diff chi tiết trước khi commit/push. Nhánh `main` và các file chưa tracked tại repo gốc được giữ nguyên vẹn.

---

## 2. Bảng trạng thái Tasks (1 – 6)

| Task | Tên nhiệm vụ | Trạng thái | Ghi chú & File mapping chính |
|---|---|---|---|
| **Task 1** | Worktree v1, khảo sát, contract dữ liệu | **HOÀN THÀNH** | Tạo worktree cô lập, ghi contract `docs/pmv/data-contract.md`. |
| **Task 2** | Nhận diện, theme v2, shell 4 tab | **HOÀN THÀNH** | App label "Quản lý PMV", copy icon mipmap từ Brand Kit; Theme `AppThemeColors` (sáng/tối), `components.dart` (MoneyText tabular, SummaryCard, SectionHeader); Shell 4 tab icon-only (`/`, `/transactions`, `/transactions/pending`, `/settings`); Settings đầy đủ lối vào, bỏ trả góp và bank balance. |
| **Task 3** | Schema/seed, Công nợ 2 chiều, reset tool | **HOÀN THÀNH** | Migration `007_pmv_catalog_debt.sql`, trigger behavior & lending, RPC `finance_apply` bỏ chặn vượt số dư, seed đầy đủ danh mục/tag; script `linux/tool/reset_pmv.py` dry-run mặc định; runbook `docs/pmv/reset-runbook.md`. |
| **Task 4** | Thu chi, Biến động, Undo 3s, offline | **HOÀN THÀNH** | Màn Biến động `pmv_bien_dong_screen.dart` tách bạch read-only bank info; gợi ý 5 danh mục + nút Khác; Công nợ chọn đúng người/khoản; Undo slot 3s lưu SharedPreferences bền vững qua restart; lưu SQLite & outbox nguyên tử. |
| **Task 5** | Tổng quan, Công nợ, Đầu tư, Ghi chú | **HOÀN THÀNH** | Tổng quan v2 tính cả Công nợ & Đầu tư vào thu/chi/chart; Màn Công nợ `debt_screen.dart` 3 nhóm (Cho vay, Vay nợ, Đã hoàn tất), nút Hoàn tất thủ công; Màn Đầu tư `investment_screen.dart` trong Cài đặt; Ghi chú ghim giữ nguyên; xóa sạch UI trả góp. |
| **Task 6** | Lịch Google, 2 Widget Android, Tests | **HOÀN THÀNH** | Dart calendar models/screen/settings; Kotlin `CalendarBridge.kt` lọc đúng `minhvu2592005@gmail.com` qua `CalendarContract.Instances`; Widget Biến động 2×2 trừ undo slot; Widget Lịch 4×2 `CalendarWidgetProvider.kt` nền tối mờ `#CC121E1E` bo góc 20dp; Viết 7 file test. |
| **Task 7** | Codex review, build APK, cutover & test A54 | **BÀN GIAO CHO CODEX** | Dành riêng cho Codex thực hiện (không giao Agy). |

---

## 3. Danh sách File thay đổi & Tạo mới

### Android Native
- `android/android/app/src/main/AndroidManifest.xml`: Đổi app label thành "Quản lý PMV", widget label "Biến động", thêm `READ_CALENDAR`, đăng ký `CalendarWidgetProvider`.
- `android/android/app/src/main/res/mipmap-*/ic_launcher.png`, `ic_launcher_round.png`: Thay bằng bộ icon chính thức từ `Quan_ly_PMV_Brand_Kit/03-android/`.
- `android/android/app/src/main/res/drawable/calendar_widget_bg.xml`: Nền tối trong suốt `#CC121E1E`, bo góc 20dp, viền ngọc.
- `android/android/app/src/main/res/layout/calendar_widget.xml`: Bố cục widget 4×2 (bên trái mini calendar tháng, bên phải ngày đã chọn & sự kiện).
- `android/android/app/src/main/res/xml/calendar_widget_info.xml`: Cấu hình AppWidgetProvider 4×2.
- `android/android/app/src/main/res/values/strings.xml`: Chuỗi định danh widget và app.
- `android/android/app/src/main/kotlin/.../MainActivity.kt`: Tích hợp `CalendarBridge`, đăng ký cập nhật widget khi app resume.
- `android/android/app/src/main/kotlin/.../banknotification/BankInboxWidget.kt`: Tự động trừ slot Undo unexpired khi hiển thị badge count.
- `android/android/app/src/main/kotlin/.../calendar/CalendarBridge.kt`: MethodChannel `personal_finance/calendar`, truy vấn an toàn calendar instances từ Calendar Provider ngoài UI thread, lọc đúng tài khoản Google.
- `android/android/app/src/main/kotlin/.../calendar/CalendarWidgetProvider.kt`: AppWidgetProvider 4×2 render dữ liệu lịch thực tế và deep link mở app.

### Flutter / Shared Core
- `linux/packages/finance_core/lib/app/theme.dart`: Hệ màu `AppThemeColors` (light/dark), `PmvColors`, tích hợp Material 3.
- `linux/packages/finance_core/lib/app/components.dart`: `AppPage`, `SectionHeader`, `SummaryCard`, `MoneyText` (font tabular figures), `SettingsGroup`.
- `linux/packages/finance_core/lib/app/router.dart`: Điều hướng 4 tab bottom navigation bar (`/`, `/transactions`, `/transactions/pending`, `/settings`), routes cho `/investments`, `/calendar`, `/calendar/settings`.
- `linux/packages/finance_core/lib/app/settings.dart`: Cài đặt nhóm rõ ràng: Công nợ, Đầu tư, Lịch, Ghi chú, Danh mục, Thẻ, Người, Tài khoản, Ngân hàng, Giao diện, Đồng bộ, Đăng xuất. Không hiển thị trả góp hay số dư ngân hàng.
- `linux/packages/finance_core/lib/core/localization/translations.dart`: Bổ sung toàn bộ từ điển tiếng Việt cho nhãn PMV.
- `linux/packages/finance_core/lib/core/utils/tag_display.dart`: Bản đồ slug ASCII → nhãn hiển thị tiếng Việt có dấu chuẩn hóa.
- `linux/packages/finance_core/lib/core/utils/ledger.dart`: Tính dòng tiền Công nợ và Đầu tư vào tổng thu/chi sổ cái; cho phép dư nợ âm; trạng thái `completed`.
- `linux/packages/finance_core/lib/core/database/record.dart`: Mặc định `manual_completed_at` cho `Entity.debts`.
- `linux/packages/finance_core/lib/features/debts/debt_service.dart`: Xử lý 4 hành động công nợ nguyên tử (`saveDisbursementTransaction`, `saveRepaymentTransaction`, `markDebtCompleted`).
- `linux/packages/finance_core/lib/features/debts/debt_screen.dart`: Giao diện Công nợ 3 nhóm (Cho vay, Vay nợ, Đã hoàn tất), nút Hoàn tất thủ công, hiển thị dư nợ âm không clamp.
- `linux/packages/finance_core/lib/features/investments/investment_screen.dart`: Màn hình Đầu tư theo dõi Vốn bỏ vào, Tiền nhận về (gốc+lãi), Chênh lệch, lọc khoảng thời gian và tag.
- `linux/packages/finance_core/lib/features/calendar/*`: Màn hình Lịch theo mẫu Samsung Calendar (lưới tháng thứ Hai đầu tuần, tên event trong ô ngày, overflow +N, shading theo số lượng event).
- `linux/packages/finance_core/lib/features/bank_import/undo_slot.dart`: Quản lý persistent undo slot 3 giây qua SharedPreferences.
- `linux/packages/finance_core/lib/features/bank_import/pmv_bien_dong_screen.dart`: Màn hình Biến động ngân hàng chuyên dụng với 5 gợi ý danh mục, chọn hành động công nợ, tạo tag inline, hoàn tác bỏ qua 3 giây.
- `linux/packages/finance_core/lib/features/bank_import/bank_confirmation.dart`: Lưu giao dịch ngân hàng liên kết công nợ nguyên tử.
- `linux/packages/finance_core/lib/features/dashboard/dashboard_screen.dart`: Tổng quan tài chính theo UI v2, tính đủ dòng tiền công nợ và đầu tư.
- `linux/packages/finance_core/lib/features/transactions/transaction_form.dart`: Loại bỏ trả góp; hỗ trợ Công nợ 4 hành động.
- `linux/packages/finance_core/lib/features/transactions/transaction_screen.dart`: Hiển thị tag tiếng Việt qua `TagDisplay`.

### Database & Tooling
- `linux/supabase/migrations/007_pmv_catalog_debt.sql`: Migration mở rộng behavior, bỏ giới hạn repayment vượt principal trong `finance_apply`, thêm `debts.manual_completed_at`, seed toàn bộ danh mục & tag tiếng Việt.
- `linux/tool/reset_pmv.py`: Script reset dữ liệu v1 có dry-run mặc định, tham số `--user-id`, xóa an toàn theo danh sách bảng allowlist trong transaction.
- `docs/pmv/reset-runbook.md`: Quy trình cutover từng bước cho Codex.
- `docs/pmv/data-contract.md`: Contract dữ liệu chuẩn.

---

## 4. Danh sách Test Files đã viết (**TẤT CẢ ĐÁNH DẤU: NOT RUN**)

Theo chỉ thị nghiêm ngặt của người dùng và Task 1–6: **Agy KHÔNG chạy test suite/build APK, không thao tác DB thật trong lượt này**. Các file test dưới đây đã được viết đầy đủ ngữ nghĩa và bàn giao cho Codex chạy:

1. `linux/supabase/tests/006_pmv_catalog_debt.sql` — **NOT RUN**
   - Kiểm tra behavior category `cong_no_expense`, `cong_no_income`, `investment_expense`, `investment_income`.
   - Kiểm tra ràng buộc hướng (direction).
   - Kiểm tra trạng thái `completed` của bảng `debts`.
   - Kiểm tra `finance_apply` cho phép repayment vượt principal (overpayment).
   - Kiểm tra tính idempotent của thủ tục seed `finance_pmv_defaults`.

2. `linux/packages/finance_core/test/pmv_debt_test.dart` — **NOT RUN**
   - Kiểm tra `Ledger.remaining` cho phép số âm khi trả vượt gốc (không clamp về 0).
   - Kiểm tra `Ledger.debtStatus` nhận diện trạng thái `completed`.
   - Kiểm tra `Ledger.monthly` tính các giao dịch công nợ vào tổng thu/chi sổ cái và loại trừ giao dịch `transfer`.
   - Kiểm tra `DebtService.markDebtCompleted` cập nhật trạng thái và `manual_completed_at`.

3. `linux/packages/finance_core/test/pmv_undo_slot_test.dart` — **NOT RUN**
   - Kiểm tra lưu/đọc `UndoSlot` từ `SharedPreferences`.
   - Kiểm tra tính hết hạn (`isExpired`) sau thời gian deadline.
   - Kiểm tra xóa slot (`UndoSlot.clear`).

4. `linux/packages/finance_core/test/pmv_investments_test.dart` — **NOT RUN**
   - Kiểm tra công thức tính: Vốn bỏ vào (Expense), Tiền nhận về (Income), Chênh lệch (Difference = Returned - Invested).

5. `linux/packages/finance_core/test/pmv_calendar_test.dart` — **NOT RUN**
   - Kiểm tra `CalendarEvent` (thuộc tính allDay, multi-day).
   - Kiểm tra `CalendarInfo` và tài khoản mục tiêu Google `minhvu2592005@gmail.com`.

6. `linux/packages/finance_core/test/pmv_navigation_theme_test.dart` — **NOT RUN**
   - Kiểm tra cấu hình 4 tab chính: Tổng quan, Thu chi, Biến động, Cài đặt.
   - Kiểm tra cấu hình màu sắc ngữ nghĩa `AppThemeColors` (sáng/tối).

7. `android/android/app/src/test/kotlin/app/personalfinance/finance_android/calendar/CalendarUnitTest.kt` — **NOT RUN**
   - Unit test Kotlin kiểm tra hằng số tài khoản Google và action intent mở lịch.

---

## 5. Hướng dẫn & Lệnh kiểm tra dành cho Codex (Task 7)

Codex thực hiện các bước sau trong môi trường worktree `/home/pmv259/Documents/personal-projects/personal-management-pmv`:

### 5.1. Chạy static analysis & unit tests Dart
```bash
cd /home/pmv259/Documents/personal-projects/personal-management-pmv/linux/packages/finance_core
flutter analyze
flutter test

cd /home/pmv259/Documents/personal-projects/personal-management-pmv/android
flutter analyze
flutter test
```

### 5.2. Chạy Android unit tests
```bash
cd /home/pmv259/Documents/personal-projects/personal-management-pmv/android/android
./gradlew :app:testDebugUnitTest
```

### 5.3. Kiểm tra SQL & Dry-run Reset
- Chạy test SQL migration trên môi trường database test cô lập:
  ```bash
  cd /home/pmv259/Documents/personal-projects/personal-management-pmv
  python linux/tool/database.py test
  ```
- Kiểm tra dry-run script reset (thay `<USER_UUID>` bằng UUID của chủ app):
  ```bash
  python linux/tool/reset_pmv.py --user-id <USER_UUID>
  ```

### 5.4. Build APK & Nghiệm thu trên Samsung A54
- Build APK:
  ```bash
  python linux/tool/flutter_client.py build --target android
  # hoặc cd android && flutter build apk --debug / --release
  ```
- Cài đặt lên thiết bị `R5CW32L96TB` qua ADB:
  ```bash
  adb -s R5CW32L96TB install -r <path_to_apk>
  ```
- Tiến hành nghiệm thu trên thiết bị theo các tiêu chí tại Mục 6 của tài liệu `docs/plans/2026-11-01-quan-ly-pmv.md`.

---

## 6. Điểm lưu ý & Rủi ro cần Codex kiểm tra

1. **Quyền Calendar trên Samsung A54:** App xin quyền `READ_CALENDAR` trực tiếp khi người dùng mở tab/màn hình Lịch lần đầu. Nếu quyền bị từ chối, màn hình và widget sẽ hiển thị thông báo cần cấp quyền rõ ràng.
2. **Widget AppWidgetId Collisions:** Các PendingIntent trong `CalendarWidgetProvider` và `BankInboxWidget` đã sử dụng request code riêng biệt và cờ `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT` để không đè lẫn nhau.
3. **Không tự động Reset DB:** Script reset có cờ an toàn, yêu cầu truyền UUID rõ ràng và chỉ thao tác khi có cờ `--execute`. Dữ liệu Auth và schema khác không bị ảnh hưởng.
4. **Không duplicate giao dịch khi liên kết Công nợ:** Thao tác tạo giao dịch và ghi nhận khoản vay/thu nợ được gói trong một `saveTransaction(..., relatedRecords: [...])` nguyên tử.
