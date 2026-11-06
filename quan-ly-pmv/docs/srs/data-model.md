# SRS — Mô hình dữ liệu và tính nhất quán

Đây là đặc tả các thực thể và ràng buộc phục vụ tính năng. Chi tiết SQL/migration là nguồn triển khai; các cột tương thích lịch sử không tạo ra tính năng sản phẩm mới.

## Thực thể chính

| Thực thể | Thông tin quan trọng | Quan hệ/ràng buộc |
|---|---|---|
| Chủ dữ liệu | ID người dùng Supabase Auth | Mọi thực thể nghiệp vụ và truy cập cloud thuộc đúng chủ |
| `accounts` | Tên, loại, tiền tệ, số dư ban đầu theo sổ, trạng thái lưu trữ | Dùng trong giao dịch/transfer; giữ tham chiếu lịch sử khi lưu trữ |
| `categories` | Tên, hướng thu/chi/cả hai, behavior, mặc định/lưu trữ | Công nợ/Đầu tư có behavior theo hướng; danh mục được dùng phải phù hợp loại giao dịch |
| `tags` | ID, tên chuẩn hóa, `category_id`, `display_name` tùy chọn | Thuộc đúng danh mục; tên hiển thị có thể giống nhau giữa các tag khác ID; giữ quy tắc tên duy nhất hiện có |
| `people` | Tên, điện thoại tùy chọn, ghi chú | Người liên quan của công nợ/ghi chú; tạo inline không làm mất form cha |
| `transactions` | Loại, purpose, số tiền nguyên, tiền tệ, ngày giao dịch, tài khoản/danh mục, mô tả, ghi chú, nguồn ngân hàng chuẩn hóa | Giao dịch chuyển nội bộ dùng from/to; dòng tiền công nợ liên kết khoản/lần thanh toán; trường nguồn ngân hàng bất biến theo quy tắc |
| `transaction_tags` | Giao dịch và tag | Liên kết đúng ID, không nhân đôi cùng cặp; retry khôi phục được liên kết thay vì tạo trùng |
| `debts` | Người, chiều `lent`/`borrowed`, gốc, tiền tệ, `started_at`, hạn trả, ghi chú, trạng thái, giao dịch gốc, mốc hoàn tất thủ công | Gốc/ngày/loại tiền nhất quán với dòng tiền gốc; trạng thái không tự hoàn tất |
| `debt_payments` | Khoản nợ, số tiền, `paid_at`, ghi chú, giao dịch liên kết | Chiều thu/chi theo khoản nợ; ngày/số tiền nhất quán với giao dịch thanh toán |
| `notes` | Tiêu đề, nội dung, ghim, mốc nhắc nhở và liên kết được hỗ trợ | Không giả định rằng lưu `reminder_at` đã tạo một hệ thống thông báo ngoài app |

## Dữ liệu cục bộ và tích hợp

| Khối | Yêu cầu |
|---|---|
| SQLite app | Bản ghi và outbox được lưu nguyên tử; thay đổi chưa sync còn sau restart |
| Pending ngân hàng native | Giữ draft gắn owner, ID/fingerprint và thông tin chuẩn hóa, phục vụ classify/ignore/retry |
| Undo slot | Owner, draft ID, deadline; tồn tại qua restart, không gia hạn khi mở lại |
| Lịch Google | Dữ liệu đọc từ hệ thống, không phải ledger; giữ instance, thời gian/cả ngày/màu/lịch con cần hiển thị |
| Cấu hình lịch dùng chung | Danh sách ID lịch đã chọn dùng chung app/widget; phân biệt chưa cấu hình với chọn rỗng |
| Cấu hình thiết bị | Theme/ngôn ngữ, nguồn ngân hàng bật và ánh xạ tài khoản theo cơ chế hiện tại |

## Metadata và thời gian

- ID và owner ổn định; metadata tạo/sửa/xóa, thời gian sửa client và mutation phục vụ đồng bộ/retry.
- `created_at` là thời điểm tạo bản ghi, không thay thế ngày thực tế giao dịch.
- Tạo/sửa gốc Công nợ: `debts.started_at` và `transactions.occurred_at` liên kết cùng chỉ một thời điểm giao dịch.
- Thu/trả: `debt_payments.paid_at` và `transactions.occurred_at` liên kết cùng thời điểm thanh toán.
- Lưu thời điểm nhất quán và hiển thị/nhóm theo giờ địa phương của thiết bị.
- Soft delete phục vụ lịch sử đồng bộ; chỉ bản ghi còn hiệu lực tham gia tổng/dư. Không hard delete để né quy tắc liên kết.

## Định danh nghiệp vụ

| Khối | Định danh/ngữ nghĩa |
|---|---|
| Loại giao dịch | `income`, `expense`, `transfer` |
| Purpose | `normal`, `debt_disbursement`, `debt_repayment` |
| Behavior danh mục | `normal`, legacy `lending`, `cong_no_expense`, `cong_no_income`, `investment_expense`, `investment_income` |
| Tag hành động Công nợ | `chovay`, `tranno`, `thuno`, `vayno`; nhãn theo [catalog](catalog.md) |
| Trạng thái công nợ | Theo dõi hiện hành và `completed` thủ công; dữ liệu legacy có thể còn trạng thái cũ. Không dùng số dư 0 để tự ghi `completed` |
| Trường loại trừ cũ | `exclude_from_totals` chỉ còn để tương thích payload; không làm phát sinh công tắc hoặc loại dòng tiền khỏi tổng |

Không chuyển nhãn UI thành khóa dữ liệu, không gộp hai danh mục thu/chi chỉ vì cùng tên, không đổi ID khi đổi theme/ngôn ngữ. Đầu tư có hai danh mục hướng khác nhau nhưng báo cáo riêng kết hợp theo loại hiển thị phù hợp.

## Quy đổi giao dịch ngân hàng USD

Khi phân loại thông báo USD, giữ nguyên số tiền nguồn và ghi sổ VND theo tỷ giá cố định 1 USD = 27,000 VND. Lưu số gốc (cent USD), loại tiền nguồn và tỷ giá trong provenance `bank_source`; số tiền giao dịch dùng VND và tham gia tổng/biểu đồ VND đúng một lần. Tài khoản ghi sổ phải là VND. Form hiển thị số USD gốc và số VND quy đổi; chi tiết giao dịch giữ thông tin nguồn. Ví dụ 22.22 USD = 599,940 VND; 0.01 USD = 270 VND. Không đổi các giao dịch đã xác nhận trước đây; retry không tạo trùng.

## Share Bill có theo dõi

- `share_bills`: bill gắn với một giao dịch Chi tiêu (`expense_tx_id`), tổng tiền, tiền tệ, số người sẽ trả lại, số lượt đã nhận, trạng thái `active`/`completed`, ghi chú và thời điểm hoàn tất.
- `share_bill_payments`: mỗi lần nhận tiền gắn với một bill và một giao dịch Thu nhập (`income_tx_id`), số tiền, ngày nhận và ghi chú.
- Hai thực thể có cùng metadata chủ sở hữu, ID ổn định, tombstone và cơ chế đồng bộ/outbox như các thực thể tài chính khác. Cloud phải hỗ trợ đọc và ghi cả hai trước khi triển khai bản app sử dụng chúng.
- Liên kết bill/giao dịch và payment/bill/giao dịch chỉ được trỏ tới dữ liệu cùng chủ sở hữu. Client không ghi trực tiếp vào bảng; thao tác ghi đi qua RPC đồng bộ có kiểm tra owner, conflict và retry idempotent.
