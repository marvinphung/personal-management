# SRS — Tổng quan và phạm vi

## Sản phẩm

**Quản lý PMV** là app tài chính và tổ chức công việc cá nhân cho một người dùng. Thiết bị sử dụng hiện tại là **Samsung Galaxy A54**. App giúp ghi thu/chi nhanh, phân loại biến động ngân hàng, theo dõi công nợ và đầu tư, lưu ghi chú và xem lịch Google.

Giao diện dùng nhận diện PMV trong brand kit, phù hợp Android/Material 3/One UI, hỗ trợ sáng/tối và ưu tiên nội dung tiếng Việt. Hỗ trợ ngôn ngữ hiện có được giữ; đổi ngôn ngữ không đổi giá trị/ID dữ liệu.

## Mục tiêu

1. Nhập số tiền và chọn danh mục/tag thuận tiện; ghi chú cá nhân chỉ là tùy chọn.
2. Phân loại thông báo ngân hàng thành sổ thu/chi mà không cần nhập lại dữ liệu nguồn.
3. Theo dõi cả cho vay và đi vay, thu/trả từng lần và hoàn tất thủ công.
4. Theo dõi vốn đầu tư và tiền thu về gồm gốc+lãi.
5. Theo dõi bill trả hộ nhóm, các lần nhận lại tiền và tiến độ hoàn tất.
6. Xem sự kiện Google Calendar theo tháng và truy cập nhanh bằng widget.
7. Lưu cục bộ và đồng bộ Supabase, giữ được dữ liệu khi mất mạng hoặc mở lại app.

## Tác nhân và hệ thống liên quan

| Tác nhân/hệ thống | Vai trò |
|---|---|
| Người dùng cá nhân | Chủ dữ liệu, nhập và sửa giao dịch, phân loại, quản lý danh mục, công nợ, đầu tư và lịch hiển thị |
| Ứng dụng ngân hàng trên A54 | Cung cấp thông báo giao dịch để bộ tiếp nhận native đọc khi đã được cho phép |
| Android/One UI | Notification Access, Calendar Provider, quyền đọc lịch và màn hình chính chứa widget |
| Supabase | Đăng nhập, lưu cloud, giới hạn truy cập theo chủ dữ liệu và đồng bộ |
| Google Calendar | Nguồn lịch cá nhân đã được đồng bộ vào Calendar Provider của thiết bị |

## Điều hướng chính

| Tab | Nội dung chính |
|---|---|
| Tổng quan | Thu nhập, chi tiêu, chênh lệch, thống kê, biểu đồ và giao dịch gần đây |
| Thu chi | Danh sách, tìm/lọc, chi tiết, tạo/sửa thu nhập/chi tiêu/chuyển khoản |
| Biến động | Các thông báo ngân hàng chờ phân loại, xác nhận hoặc bỏ qua/hoàn tác |
| Cài đặt | Công nợ, Share Bill, Đầu tư, Lịch, Ghi chú, quản lý dữ liệu, ngân hàng, giao diện, ngôn ngữ và đồng bộ |

Thanh điều hướng chỉ hiện icon; tooltip và nhãn hỗ trợ tiếp cận vẫn có. Công nợ và Đầu tư không có tab chính riêng; dòng tiền của chúng vẫn tham gia tổng thu/chi.

## Ranh giới

- App hiện tại là PMV phát triển từ v1; app v2 cũ **Quản lý Tao** chỉ là nguồn tham khảo giao diện trong lịch sử. Không dùng quy trình duyệt người dùng hoặc kiến trúc collector/backend của app đó làm yêu cầu PMV.
- Nền tảng sản phẩm hiện tại: Android A54. Mã desktop hoặc lịch sử iOS không tạo yêu cầu triển khai đa nền tảng mới.
- Cloud tiếp tục là Supabase; local tiếp tục phục vụ offline và hàng đợi đồng bộ. Không cần thêm FastAPI, NATS/JetStream hoặc điện thoại collector riêng.
- Không có chức năng trả góp hoặc công tắc loại trừ Công nợ/Đầu tư khỏi tổng thu/chi.
- Lịch chỉ đọc: không tạo/sửa/xóa sự kiện Google từ PMV. Không hiển thị ngày âm.
- Không hiển thị số dư tài khoản lấy từ nội dung thông báo ngân hàng. Việc tính số dư theo sổ giao dịch trong quản lý tài khoản được phân biệt với số dư ngân hàng này.
- Không tự xác định/chốt thông báo chuyển khoản giữa các tài khoản; người dùng quyết định phân loại hoặc bỏ qua.

Các yêu cầu chi tiết: [tính năng](features.md), [nghiệp vụ](business-rules.md), [dữ liệu](data-model.md) và [nghiệm thu](acceptance.md).
