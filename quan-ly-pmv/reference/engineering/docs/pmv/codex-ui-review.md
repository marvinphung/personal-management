# Codex review giao diện — 04/11/2026

Branch: `feature/pmv-ui-refresh`, nền `20b73e3`. Giữ nguyên thiết kế Claude và sửa trực tiếp các lỗi nghiệm thu. Bản chuẩn bị cài: **1.2.0+7**.

## Các lỗi đã sửa

| Mức | Phát hiện | Kết quả |
|---|---|---|
| Chặn chạy | `catalog_screen.dart`: thiếu dấu đóng `showDialog` ở Chi tiết tài khoản | Sửa cú pháp; toàn bộ app biên dịch được |
| Cao | `SummaryCard` dùng `balanceMinor.abs()`, làm mất dấu âm khi bội chi | Hiển thị đúng số âm; thêm test hồi quy |
| Cao | Tràn ở header biểu đồ, nhãn phần, Công nợ, Đầu tư, hàng phân trang Biến động và sidebar | Bố cục co giãn/xuống dòng; kiểm tra khổ A54 và chữ 130% |
| Vừa | Form toàn màn hình vừa resize theo bàn phím vừa cộng thêm inset vào padding | Bỏ cộng inset hai lần; nút Lưu và trường cuối truy cập được khi bàn phím mở |
| Vừa | TextField tiền mới không có nhãn gắn với trường; nút loại giao dịch chỉ biểu thị chọn bằng màu | Thêm semantics cho ô tiền và trạng thái nút; vùng chạm đủ 48dp |
| Vừa | Chữ muted và ngày Lịch tô đậm có tương phản thấp; chữ trắng trên sự kiện màu vàng khó đọc | Điều chỉnh màu muted; chọn chữ theo nền thực tế, giữ màu lịch và mật độ shading |
| Vừa | SwitchListTile nằm sau nền Container, che ink/background và gây cảnh báo Flutter | Thêm Material phù hợp ở form danh mục/ghi chú |
| Vừa | Một số nhãn chung bị hardcode tiếng Việt, làm mất cách gọi theo locale trước đó | Khôi phục localization cho điều khiển chung/trường chính; giữ nhãn mới phù hợp thiết kế |
| Nhẹ | Global Search có thể hiển thị slug tag thay vì display_name | Dùng nhãn tag người dùng đọc được |
| Nhẹ | Import thừa và API dropdown deprecated | Dọn sạch cảnh báo analyze |

Các test cũ được đổi selector khi UI thực sự đổi (dropdown sang segment, nút Hủy sang icon đóng, nhãn/bố cục mới). Vẫn kiểm tra số tiền chính xác, category/tag ID, lưu và chỉnh sửa thật trong SQLite/outbox; không bỏ assertion nghiệp vụ để làm test qua.

## Đã xác minh

- **113 test finance_core: PASS**.
- **1 test Android launcher: PASS**.
- **23 Kotlin/native unit test: PASS**, không failure/error/skipped.
- Analyze finance_core và Android launcher: **No issues found**.
- APK release ký bằng cấu hình signing hiện có: **BUILD PASS**.
- `git diff --check`: PASS.
- Các luồng được kiểm tra: tiền tự thêm dấu phẩy, tạo người inline, Công nợ hai chiều, ngày quá khứ, sửa khoản nợ/Đầu tư, Mua chung/share bill, nguồn ngân hàng read-only, Undo, lịch sáu tuần và lựa chọn ngày, ngôn ngữ, theme sáng/tối.
- Test bổ sung cho dấu âm tổng quan, tương phản, lịch dày sự kiện, trường cuối/nút Lưu khi có bàn phím và màn hình A54 ở text scale 130%.
- Không thay schema, repository, debt service hay dữ liệu Supabase trong đợt review này.

## Chưa nghiệm thu trên điện thoại thật

ADB hiện không liệt kê thiết bị, kể cả USB và mDNS. Người dùng đã được đề nghị kết nối/mở khóa A54. **Chưa cài bản 1.2.0 và chưa xác nhận trực quan trên A54**, gồm hai widget trên One UI Launcher. Không coi test mô phỏng là nghiệm thu thiết bị.

APK: `android/build/installers/quan-ly-pmv-1.2.0.apk`.
Log kiểm tra local: `artifacts/pmv-ui-review-2026-11-04/` (được gitignore).

Chưa commit/push/merge thay đổi UI trong đợt review này.
