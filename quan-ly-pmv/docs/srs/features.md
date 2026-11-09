# SRS — Tính năng

Mỗi mã `FR` đại diện một nhóm yêu cầu hiện hành. User story và tiêu chí chấp nhận tham chiếu các mã này.

| Mã | Tính năng | Yêu cầu |
|---|---|---|
| FR-01 | Đăng nhập và phiên | Sử dụng Supabase Auth; giữ phiên theo cơ chế hiện có; dữ liệu thuộc chủ đã đăng nhập; không có bước duyệt bởi quản trị viên của app v2 cũ |
| FR-02 | Điều hướng và giao diện | Bốn tab icon-only; chức năng phụ trong Cài đặt; theme sáng/tối/hệ thống; giữ hỗ trợ ngôn ngữ và nhận diện PMV |
| FR-03 | Tổng quan | Xem theo tháng/tiền tệ: thu, chi, chênh lệch có dấu, tỷ lệ tiết kiệm, dư công nợ, chi theo ngày/danh mục/tag và giao dịch gần đây |
| FR-04 | Thu/chi thủ công | Tạo thu nhập/chi tiêu với số tiền, ngày giao dịch, tài khoản và danh mục; tag và ghi chú tùy chọn với giao dịch thường; nhập tiền có dấu phẩy tự động |
| FR-05 | Tìm/lọc và chỉnh sửa | Danh sách nhóm theo ngày; tìm/lọc theo nội dung, danh mục, tag, tài khoản, loại; mở chi tiết và sửa trường cho phép; quản lý giao dịch công nợ qua khoản liên kết |
| FR-06 | Chuyển khoản nội bộ | Chọn hai tài khoản khác nhau và cùng tiền tệ; ghi một lần chuyển; không làm tăng tổng thu/chi |
| FR-07 | Danh mục/tag/tài khoản | Duy trì dữ liệu phân loại, danh mục theo hướng thu/chi và tag gắn đúng danh mục; hiển thị tên tiếng Việt; lưu trữ mục có hỗ trợ mà không làm mất lịch sử |
| FR-08 | Người liên quan | Chọn, tạo và chỉnh người liên quan; thêm inline dùng được cả khi danh sách trống; giữ dữ liệu form đang nhập |
| FR-09 | Tiếp nhận ngân hàng | Nhận thông báo mới từ ngân hàng được hỗ trợ/bật, lưu chờ phân loại ở native; thể hiện rõ quyền đọc thông báo, bật thu thập và trạng thái dịch vụ là các trạng thái khác nhau |
| FR-10 | Phân loại biến động | Hiện hướng tiền, số tiền, tiền tệ, ngân hàng, thời gian và nội dung nguồn; gợi ý năm danh mục theo hướng thu/chi cùng nút Khác; chọn danh mục/tag/ghi chú rồi xác nhận vào sổ đúng một lần |
| FR-11 | Bỏ qua/hoàn tác | Ẩn tức thời thông báo bỏ qua, cho hoàn tác trong 3 giây, giữ deadline qua restart; chỉ bỏ hẳn sau khi native xử lý thành công |
| FR-12 | Công nợ hai chiều | Tạo Cho vay hoặc Vay nợ; ghi Thu nợ/Trả nợ vào khoản đã chọn; chọn ngày quá khứ, tài khoản thanh toán tùy chọn, hạn trả riêng/tùy chọn |
| FR-13 | Theo dõi/sửa công nợ | Hiện gốc, các lần thu/trả và còn lại có thể âm; sửa thông tin cho phép đồng bộ với giao dịch liên kết; chỉ hoàn tất bằng nút Hoàn tất và giữ lịch sử |
| FR-14 | Đầu tư | Ghi chi vốn và thu tiền gồm cả gốc+lãi; tổng hợp vốn bỏ vào, tiền nhận về và chênh lệch; lọc thời gian/loại đầu tư; mở lại để sửa |
| FR-15 | Mua chung/Share Bill có theo dõi | Giữ tag Mua chung và danh mục Nhận share bill; tùy chọn tạo bill khi ghi chi thủ công hoặc phân loại biến động tiền ra, nhập tổng số người gồm bạn và số người đã trả; liên kết lần nhận tiền thủ công/ngân hàng qua thanh gạt, mặc định đã trả 1 (chính bạn) khi tạo bill; mỗi lần nhận mặc định 1 người và có −/+; sửa bill/lần nhận, xem tiến độ/lịch sử và hoàn tất tự động hoặc thủ công trong Cài đặt → Share Bill; thống kê chỉ tính phần chi cá nhân, nhận lại không tính tổng thu |
| FR-16 | Ghi chú | Tạo/sửa/tìm ghi chú, ghim, lưu mốc nhắc nhở và liên kết được hỗ trợ; không suy diễn lưu mốc nhắc nhở thành một dịch vụ phát thông báo mới |
| FR-17 | Lịch Google | Đọc lịch cá nhân đã cấu hình từ Android Calendar Provider; chọn lịch con hiển thị; mặc định tháng, thứ Hai đầu tuần, ngày có nhiều việc tô đậm hơn; xem sự kiện của ngày |
| FR-18 | Widget | Lịch 4×2: tháng bên trái, ngày/sự kiện bên phải; Biến động 2×2: số lượng chờ và mở đúng tab; giữ liên kết ngày/app và lựa chọn lịch dùng chung |
| FR-19 | Cài đặt và đồng bộ | Quản lý theme/ngôn ngữ, cấu hình ngân hàng/lịch, xem trạng thái và retry đồng bộ, đăng xuất; Cài đặt Ngân hàng có nút Debug kiểm tra/thử khôi phục bộ đọc và báo kết quả thật; chức năng Công nợ/Share Bill/Đầu tư/Lịch/Ghi chú truy cập được tại đây |
| FR-20 | Offline và tính nhất quán | Lưu local trước, outbox bền vững, đồng bộ lại khi có mạng; retry không nhân đôi khoản/giao dịch; không lẫn dữ liệu giữa các chủ |

## Trường chung khi nhập giao dịch

- **Số tiền:** bắt buộc, giá trị dương; hiển thị nhóm hàng nghìn khi gõ/dán, không thay đơn vị hoặc làm sai giá trị.
- **Ngày giao dịch:** mặc định ngày hiện tại; ghi lùi được cho giao dịch thủ công. `Ngày tạo bản ghi` là thông tin khác.
- **Danh mục:** phù hợp loại thu/chi; chọn đúng hành động nếu là Công nợ.
- **Tài khoản:** giao dịch thường/chuyển khoản tuân thủ ràng buộc tài khoản; Công nợ cho phép bỏ trống tài khoản thanh toán.
- **Tag:** tùy chọn đối với giao dịch thường; hành động Công nợ là bắt buộc; Mua chung là tag bổ sung.
- **Ghi chú riêng:** tùy chọn. Các tag gợi ý cần đủ bao quát để hạn chế phải ghi chú lại hoạt động thường gặp.
- **Giao dịch từ ngân hàng:** không sửa các trường nguồn đã xác nhận; xem [quy tắc nghiệp vụ](business-rules.md).

Không thay đổi ý nghĩa tính toán chỉ vì thay kiểu control, kích thước form hay bố cục.
