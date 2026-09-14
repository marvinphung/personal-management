# Số dư ngân hàng và trả góp — 14/09/2026

## Thiết kế đã triển khai

- Parser Kotlin trích riêng `balanceMinor`/`balanceCurrency` từ SD/Số dư/Balance, không thay thế số tiền giao dịch. Cho phép số dư bằng 0 hoặc âm, tính bằng số nguyên VND/USD. Thất bại/mơ hồ không cập nhật.
- Native inbox lưu snapshot mới nhất theo tài khoản đã ánh xạ trong cấu hình Android, xóa cùng dữ liệu chủ tài khoản khi đăng xuất. Hoạt động khi không có Flutter. Không lưu/upload raw text.
- MethodChannel `balances` truyền snapshot chuẩn hóa vào FinanceRepository. Startup/resume/sự kiện native cập nhật local/outbox; Supabase đồng bộ như account thông thường. Khi Flutter đóng, việc chuyển sang Drift và cloud chờ mở app.
- `accounts.bank_balance` và `bank_balance_at` là mốc đối soát; số dư = mốc + ledger sau mốc. Không có mốc dùng opening_balance. Trigger PostgreSQL giữ mốc mới nhất khi thiết bị cũ cập nhật; RLS hiện có giữ nguyên. Thay đổi tiền tệ xóa mốc cũ.
- Duyệt thông báo để trống mô tả và danh mục; vẫn dùng form/repository hiện tại, không tự xác nhận.
- Trả góp nhập tiền tháng, số tháng 1–60, ngày 1–31 (mặc định 24). Các kỳ bắt đầu tháng sau ngày mua, clamp ngày cuối tháng. Tạo cả chuỗi + tags trong một local/outbox transaction, UUID xác định theo nhóm, retry không tạo trùng. Không cần scheduler/server và không tạo khoản tổng ban đầu.
- Kỳ tương lai có sẵn trong danh sách tháng nhưng chưa ảnh hưởng tiền hiện có/thống kê. UI làm mới theo phút. Sửa/xóa từng kỳ qua form hiện tại; không tự trích tiền ngân hàng.

## File chính

- Native `banknotification/parser/{BankMoney,ParsedBankTransaction,BankNotificationParser}.kt`, `BankInbox.kt`, `bridge/BankDraftFlutterBridge.kt`.
- Shared `features/bank_import/{bank_draft,bank_draft_repository}.dart`, `features/transactions/{installments,transaction_form,transaction_screen}.dart`.
- Shared `core/database/{finance_repository,local_database}.dart`, `core/utils/ledger.dart`, `app/{app,providers}.dart`, catalog/dashboard, bản dịch.
- Migration `004_bank_balances_installments.sql`; SQL test `003_bank_balances_installments.sql`.
- Tests `bank_balance_test.dart`, `installment_test.dart`, `bank_import_test.dart`, `widget_test.dart`, native ParserTest/ListenerTest.

## Đã kiểm tra

- Shared Flutter: 60 tests passed; sau bổ sung khóa cập nhật số dư, chạy lại 14 tests repository/form/inbox liên quan, đều qua.
- Kotlin/Robolectric: 15 tests passed, gồm listener lưu số dư khi không có Flutter, không ghi đè bằng thông báo cũ, xóa khi logout.
- Analyzer shared/Android/Linux sạch; mỗi launcher 1 test qua.
- Migration đã áp dụng; cả 3 bộ SQL/RLS test qua, dữ liệu test rollback.
- APK debug build thành công, đã cài cập nhật trên Samsung R5CW32L96TB. Linux release build thành công sau khi chuyển cache CMake cũ sang /tmp. Không giả lập giao dịch thật vào dữ liệu của người dùng.

## Giới hạn

- Một nguồn ngân hàng ánh xạ một tài khoản. Chưa tự phân biệt nhiều thẻ/tài khoản trong cùng app ngân hàng.
- Số dư có nghĩa tại thời điểm thông báo; thông báo thiếu ngày giờ dùng giờ nhận, chưa xử lý hoàn hảo những giao dịch cùng timestamp hoặc thông báo đến chậm.
- Chưa có đối soát thủ công hoặc sửa/hủy toàn chuỗi. Giới hạn 100 dòng mỗi operation gồm liên kết tags.
- Chưa kiểm chứng một thông báo ngân hàng thật mới đến sau khi cài bản này; unit/integration tests dùng mẫu giả.
