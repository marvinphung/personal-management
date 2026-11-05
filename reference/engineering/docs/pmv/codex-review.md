# Codex review — Quản lý PMV, lượt 1

Đây là review ban đầu trước khi sửa. Tình trạng khắc phục xem [codex-fix-report.md](codex-fix-report.md).

Verdict lúc review ban đầu: **REQUEST CHANGES**. Không duyệt trạng thái task 1–6 hoàn tất. Chưa build/cài APK, chưa chạy migration/reset cloud hoặc xóa dữ liệu điện thoại.

## Bằng chứng thực chạy

- Worktree: `/home/pmv259/Documents/personal-projects/personal-management-pmv`, source Agy chưa commit.
- `flutter analyze` tại `linux/packages/finance_core`: exit 1, **52 issues**, gồm lỗi biên dịch (không phải chỉ lint).
- `flutter test --reporter expanded`: hoàn tất, **49 pass, 11 failure entries**, gồm lỗi load/compile và kỳ vọng cũ loại công nợ khỏi tổng. Log: `/tmp/pmv-review-flutter-test.log`. Shell wrapper chạy tail sau test nên exit code của wrapper không đại diện exit code test; kết quả FAIL xác nhận từ dòng Some tests failed trong log.
- Không chạy Kotlin/SQL/cloud reset hoặc build sau khi đã xác nhận source Dart chưa biên dịch; tiếp tục kiểm tra các phần này sau sửa.
- Đây là findings xác nhận từ source và analyzer; chưa phải review bao phủ mọi dòng hoặc chứng nhận schema an toàn.

## R1 — P1: Source không biên dịch

Analyzer xác nhận:
- `lib/app/router.dart:87`: CalendarSettingsScreen không tồn tại/không được resolve.
- `lib/app/search.dart:109`, `features/catalog/catalog_screen.dart:109`: showPersonDetail bị xóa nhưng callers còn dùng.
- `core/localization/translations.dart:340–341`: khóa trùng trong const map.
- `features/bank_import/bank_providers.dart:74,92`: Entity chưa import và export đặt sau declaration.
- `features/calendar/calendar_providers.dart:20,28,172`: StateProvider/StateNotifier/StateNotifierProvider không resolve với import Riverpod hiện tại, kéo theo hàng loạt lỗi state.
- `test/pmv_debt_test.dart:113`: gọi sai constructor FinanceRepository.

Sửa root causes, không xóa test/ẩn code tính năng để analyzer im lặng. Xem toàn bộ analyzer output khi chạy lại; danh sách này không bao gồm mọi warning/info.

## R2 — P1: Vẫn chặn thu/trả vượt dư nợ tại repository

`lib/core/database/finance_repository.dart:248–256` vẫn so payment với Ledger.remaining và ném Repayment exceeds the remaining debt. Migration bỏ check SQL không làm luồng local hoạt động. Bỏ check đúng nơi, giữ amount/ownership/currency/direction validation. Viết test gọi DebtService → repository → SQLite thật cho đủ bốn action và overpayment, kiểm tra outbox; test Ledger.remaining đơn thuần không chứng minh được.

## R3 — P1: Widget Lịch chưa được triển khai như đặc tả

`android/.../res/layout/calendar_widget.xml:37–46` chỉ có một TextView tĩnh T2…CN, không có grid ngày. `CalendarWidgetProvider.kt` chỉ ghi tháng, count và lịch hôm nay, không ghi calendar_widget_left_body, không có day shading hoặc ngày chọn. Cần render lưới tháng thật, màu theo số instances, selected day/events, click theo ngày và overflow/resize; không thay yêu cầu bằng summary tháng.

## R4 — P1: Widget bỏ qua lựa chọn lịch của người dùng

`CalendarWidgetProvider.kt:queryGoogleCalendarIds` lấy mọi calendar của account, không đọc selected calendar IDs và không dùng visible/sync default. Dart `calendar_repository.dart:63–74` chỉ lưu selection trong prefs; widget không sử dụng. Người dùng bỏ chọn lịch nhưng widget vẫn hiển thị sự kiện. Tạo shared native selection contract và test bỏ chọn/chọn rỗng, app/widget giống nhau, không lẫn account.

## R5 — P1: Undo có thể hồi sinh giao dịch đã bỏ qua

`pmv_bien_dong_screen.dart:86–104` tìm draft chỉ trong trang provider hiện tại, xóa slot trước khi native finish, không có draft thì vẫn bỏ slot, lỗi finish bị nuốt. Restart khi provider chưa tải hoặc đổi trang làm mất quyết định bỏ qua. `dispose:47–49` hủy timer; finalize phụ thuộc màn hiện tại nên ra khỏi Biến động có thể ngăn hoàn tất. Cần coordinator độc lập screen, finalize theo owner/id, giữ durable state đến khi ACK, retry lỗi; serialize undo/discard mới và xác thực slot identity/generation. Test delayed finish, restart, đổi tab/trang, lỗi native, hai discard liên tiếp và owner change.

## R6 — P1: Deep link lịch chưa có đường nhận ở native

`MainActivity.kt:31–35` chỉ đưa onNewIntent vào bankBridge. CalendarBridge không nhận ACTION_OPEN_CALENDAR/date và không có initial-intent contract cho Lịch. Widget tạo pmv://calendar nhưng chưa có mapping consume-once đảm bảo tới router. Triển khai cold/warm/after-login pending target, giữ ngày và consume đúng một lần; verify không tự nhảy Lịch ở resume sau đó.

## R7 — P1: Reset sai thứ tự FK, không thể dùng làm runbook cutover

`linux/tool/reset_pmv.py:20–30` xóa debt_payments/debts/transactions trước notes. Schema `001_finance.sql:177` có notes.debt_id và notes.transaction_id foreign keys không cascade. Khi có note liên kết, reset lỗi và rollback. Xóa notes trước các parent; viết fixture có tất cả links và hai user để chứng minh chỉ user đích bị xóa, dry-run không ghi. Runbook đang bảo chạy script này nên chưa được phép coi cutover ready.

## R8 — P2: Lịch không có native observer như code Dart giả định

`calendar_providers.dart:34–44` chờ onCalendarChanged nhưng CalendarBridge.kt không đăng ký ContentObserver hay gửi event này. Permission request trả false ngay sau mở dialog, không trả kết quả qua callback; phải có refresh/resume và trạng thái rõ sau grant/revoke. Đọc observer/lifecycle/date/timezone changes, debounce/background query; test permission grant/revoke và event thêm từ app Google Calendar xuất hiện mà không cần reset.

## R9 — P2: Bộ test chưa chứng minh các hành vi được báo hoàn thành

- `pmv_investments_test.dart`: tự tính sum trong test, không gọi calculator/query/UI production; không bắt được sai lọc tiền/tags/history.
- `CalendarUnitTest.kt`: chỉ so hằng account/action, không test provider query, widget render, selection hoặc deep link.
- `006_pmv_catalog_debt.sql:69–73`: nhóm tên được đếm có 7 category rows nhưng expect 6. Test trực tiếp gọi finance_pmv_defaults trong khi function bị revoke với authenticated; cần khớp role của suite và test public RPC đúng quyền. Chưa chạy SQL nên ghi đây là lỗi đọc source cần sửa/kiểm chứng, không báo SQL đã fail thực tế.

Thêm test vào production paths: repository payments, durable undo, widget grid/selection/deep link và seed dưới role thật. Không sửa expectation mù quáng theo output; giữ regression cũ hoặc ghi lý do đổi kỳ vọng khi yêu cầu sản phẩm thay đổi.

## R10 — P2: Lọc loại Đầu tư chia rời thu/chi

Seed dùng tag IDs/slugs khác nhau ở hai chiều (ví dụ chungkhoan và chungkhoanthu). `investment_screen.dart:49–51,73–79` dựng chip theo từng tag ID và lọc nguyên ID, khiến hai chip cùng nhãn Chứng khoán nhưng mỗi chip chỉ lấy một chiều, dễ làm người dùng thấy chênh lệch sai khi lọc một loại. Dùng stable investment kind để gom cả hai hướng trong một lựa chọn; test bỏ vốn và nhận tiền cùng loại, nhiều tag và range thời gian.

## Thứ tự sửa để bàn giao lại

1. R1 compile; R2/R5 integrity; R7 reset (source/script, chưa chạy cloud).
2. R3/R4/R6/R8 lịch + widget đúng luồng; R10 investment filter.
3. R9 tests thực tế, cập nhật contract/runbook/handoff và trạng thái partial còn lại.
4. Giữ phần chạy kiểm thử/build/thiết bị/cutover cho Codex như phân công cũ. Không tự nhận tất cả hoàn tất khi chỉ có source skeleton.

Không cần thay đổi yêu cầu người dùng để sửa các lỗi này. Không deploy/reset/cài app trong lượt Agy sửa.
