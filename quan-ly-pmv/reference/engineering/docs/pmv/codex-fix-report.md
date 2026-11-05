# Quản lý PMV — Codex sửa lỗi và nghiệm thu

Ngày: 02/11/2026. Worktree `personal-management-pmv`, branch `feature/quan-ly-pmv`, base v1 `b23913b`. Source chưa commit/push.

## Checklist R1–R10

| Finding | Sửa ở đâu / bằng chứng |
|---|---|
| R1 — Không biên dịch | Sửa router, Riverpod imports, duplicate localization keys, Entity import, khôi phục PersonDetail/callers và test constructor; analyze sạch ở lượt kiểm tra gần nhất. |
| R2 — Overpayment | Bỏ chặn tại repository, giữ kiểm tra tiền dương/đúng currency/direction; test DebtService → SQLite/outbox cả lent/borrowed, số dư âm, hoàn tất thủ công. |
| R3 — Widget thiếu lưới | RemoteViews thực 42 ô, shading theo số sự kiện, panel ngày chọn, click ngày và mở app; đã đặt widget 4×2 trên Home Screen A54 và quan sát lưới thật. |
| R4 — Selection không đồng bộ | CalendarData là nguồn native chung; Dart truy cập selection qua channel; mặc định visible+sync, explicit empty không fallback. Đã bỏ chọn cả ba lịch trên A54, xác minh widget trống, rồi phục hồi lựa chọn cũ. |
| R5 — Undo mất quyết định | UndoController sống ở cấp app, khóa serialize, finish theo owner/id không phụ thuộc page, giữ slot tới ACK, retry lỗi, chống stale undo; tests restore/retry/discard kế tiếp. |
| R6 — Deep links | Native navigation channel giữ target và consume-once; Flutter chờ auth/language, route Lịch có date, cập nhật ngày khi warm route thay đổi; chuyển Settings lịch sang route khai báo thay imperative page. |
| R7 — Reset FK | Xóa notes trước parent, transaction + user advisory lock; test dry-run/linked notes/hai user/Auth. Reset cloud thực đã hoàn tất với backup và phạm vi v1. |
| R8 — Lifecycle Lịch | Observer debounce, background queries, callback quyền, kiểm tra quyền trước đăng ký observer (sửa crash thực tế trên A54), refresh/resume và state error rõ. |
| R9 — Tests yếu | Bổ sung test production paths: repository/debt, durable undo, investment filtering, calendar grouping/UI 6 tuần/native query selection/widget render/permission; SQL theo style suite hiện có, không phụ thuộc pgTAP. |
| R10 — Đầu tư lọc lệch chiều | Một lựa chọn loại gộp tag IDs hai chiều; InvestmentSummary.filter dùng cả vốn và thu hồi, range/currency/deleted và lịch sử category archived; regression test đi qua calculator thật. |

## Sửa thêm khi kiểm tra luồng thật

- Biểu đồ chi từng ngày tính cả Công nợ; trang tài khoản bỏ số dư/mốc số dư ngân hàng.
- Bank transaction lưu provenance chuẩn hóa và nội dung đã parse; immutable amount/currency/type/time/description được kiểm tra tại local repository và PostgreSQL. Category/tag/note còn chỉnh được; không lưu raw notification payload lên cloud.
- Bổ sung lựa chọn tài khoản ngay khi phân loại nếu chưa đặt tài khoản mặc định; category fallback đủ năm mục khi lịch sử ít.
- Công nợ không tự chuyển paid khi số còn lại bằng 0; nút Hoàn tất là quyết định thủ công. Thu/trả ở màn Công nợ yêu cầu tài khoản và liên kết category/action tag khi có PMV seed.
- CalendarGrid tính chiều cao sáu hàng theo không gian thật; không cắt ngày cuối tháng. Bỏ hai appbar Lịch, bỏ FAB giao dịch ở chức năng phụ, tab Settings active khi vào chức năng từ Settings.
- Icon legacy/adaptive/monochrome và splash Android 12+, giữ đúng brand kit.
- Build script chỉ dùng signing identity đã có, không tự tạo khóa thay thế. Khóa và credentials cục bộ nằm trong đường dẫn Git ignored.

## Cloud cutover đã thực hiện

- Kết nối SSL tới đúng project có public client URL khớp project ref, xác nhận migrations 001–006 trước khi chạy.
- Chỉ một Auth user sở hữu dữ liệu v1. Force-stop v1 trước khi xóa cache/outbox; không dừng hay sửa app v2.
- Backup riêng dữ liệu v1 trước reset: `/home/pmv259/.local/share/pmv-backups/v1-before-pmv-20261101T170105Z.json`, quyền 0600. File chứa dữ liệu riêng tư, không đưa vào Git/artifacts chia sẻ.
- Migration 007 và reset/seed v1 commit trong cùng transaction. Có đúng 12 danh mục chi, 7 danh mục thu; lịch sử giao dịch/công nợ/ghi chú cũ đã xóa theo yêu cầu.
- Không chạy mutation vào auth.users hoặc qlt; Auth ID còn nguyên, row counts của 26 bảng qlt trước/sau bằng nhau.
- Xóa có chọn lọc cache ledger SQLite, inbox Room, cấu hình bank import cũ và undo trên A54. Giữ secure session storage; bản mới đã phục hồi phiên đăng nhập.
- Sau reset tạo cấu hình tài khoản trống Tiền mặt, MB Bank, VietinBank để dùng app và map nguồn thử. Không tạo giao dịch tài chính giả trên cloud.
- Nhập thông báo đã bật lại trên A54; Notification Access vẫn bật, listener báo Đã kết nối; MB/VietinBank có account mapping đúng.

## Kiểm tra đã chạy

- Flutter shared analyze sạch; toàn bộ **91 tests pass** ở lượt cuối, gồm account-picker regression. Logs trong `artifacts/pmv-verification-2026-11-02/`.
- Android launcher: analyze sạch; 1 test pass.
- Kotlin/Robolectric: 23 tests, 0 failures/errors/skips, gồm widget thật và permission/Calendar Provider adapter.
- PostgreSQL 16 test cô lập trong Docker, loopback port 55439: chạy migrations 001–007 trên DB mới và cả 6 SQL/RLS suites trong rollback transaction, pass. Không chạy fixture SQL vào cloud.
- Reset tool integration: linked notes + hai user + Auth preservation + dry-run, pass trên database test.
- Release APK đã build/cài đè trên A54 bằng certificate SHA-256 trùng bản cũ. Version 1.1.0+2; không uninstall hoặc đổi signing identity.
- Thiết bị: khởi động, giữ login, bốn icon tabs, cấp READ_CALENDAR qua dialog hệ thống, đọc event thật, month view, selection và widget Calendar 4×2. Cả Calendar widget và Inbox widget 2×2 đã được đặt lên Home Screen.

## Kiểm chứng biến động ngân hàng

Hai notification thử MB/VietinBank đầu tiên được người dùng phát trước khi bật lại capture sau reset; chúng còn trên notification shade nhưng không được tự nhập ngược theo cutoff. Không coi hai notification đó là bằng chứng capture end-to-end thành công. Đã bật lại capture và map account. Lượt chuyển thử tiếp theo đã được xác minh trên A54: 5 draft thực trong Biến động, có cặp MB→BIDV và MB→VietinBank khớp số tiền/chiều. Không duyệt bất kỳ draft nào vào ledger. BIDV hiện dùng thời điểm nhận thông báo và UI có cảnh báo thời gian ước tính; MB/VietinBank hiển thị thời gian giao dịch.

Chỉ đọc các notification keys thuộc ngân hàng được hỗ trợ; không thu thập chat/OTP/lịch sử thông báo. Không lưu raw notification, token, DB password hoặc nội dung sự kiện cá nhân vào report. Screenshot kiểm tra có nội dung lịch cá nhân được giữ ngoài repository, không dùng làm artifact chia sẻ.

## Bàn giao và giới hạn

- APK: `android/build/installers/quan-ly-pmv-1.1.0.apk`; SHA-256 `734902092eccfd80cd8a3897dc1eedeef8ed7858d40579da8f4ac88ccc392e08` (đối chiếu bản cài cuối trong verification.json).
- Không merge/push trong lượt sửa này.
- Các trạng thái force-stop, quyền bị thu hồi và hạn chế pin của Samsung vẫn thuộc kiểm soát Android. Native service không thể đọc thông báo đã bị xóa lúc dịch vụ không nhận được.
- Không tự duyệt giao dịch chuyển thử của người dùng vào sổ; việc xem draft/phân loại thử phải tách khỏi xác nhận tài chính thật.

## Follow-up: totals exclusion and editing (1.1.2+4)

See [verification report](totals-exclusion-verification.md) for per-item switches, debt editing, investment entry/editing, migration 009, 101 passing shared tests, seven SQL suites, and A54/cloud verification.

## Follow-up: debt dates and always-count totals (1.1.3+5)

The user retired totals exclusion. See [current verification](debt-dates-verification.md) for selecting historical loan/repayment dates, retaining edits, migration 010 and test results.
