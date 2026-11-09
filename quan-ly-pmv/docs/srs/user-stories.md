# SRS — User story

Tác nhân của các story là người dùng cá nhân của Quản lý PMV.

| Story | Nhu cầu | Kết quả chấp nhận | FR |
|---|---|---|---|
| US-01 | Tôi muốn đăng nhập lại mà vẫn thấy dữ liệu của mình | Phiên và dữ liệu đúng chủ; không phải đi qua duyệt admin | FR-01, FR-20 |
| US-02 | Tôi muốn chuyển chức năng nhanh bằng icon | Bốn tab có đúng nội dung, tooltip/nhãn đọc được; Công nợ/Đầu tư nằm trong Cài đặt | FR-02, FR-19 |
| US-03 | Tôi muốn biết tháng này thu, chi và chênh lệch bao nhiêu | Tổng đúng kỳ/tiền tệ; chênh lệch âm có dấu âm; biểu đồ khớp sổ | FR-03 |
| US-04 | Tôi muốn ghi khoản chi tiền mặt vừa nhớ ra | Chọn được ngày thực tế, danh mục/tag; ghi chú có thể để trống | FR-04 |
| US-05 | Tôi muốn nhập 1000000 mà không nhầm số 0 | Ô nhập hiện 1,000,000 ngay khi gõ; lưu đúng 1.000.000 VND | FR-04 |
| US-06 | Tôi muốn tìm và chỉnh giao dịch đã lưu | Tìm/lọc được, mở chi tiết và chỉ sửa các trường cho phép; thống kê cập nhật | FR-05 |
| US-07 | Tôi muốn chuyển tiền giữa hai tài khoản của mình | Hai số dư sổ giao dịch thay đổi phù hợp nhưng tổng thu/chi không tăng | FR-06 |
| US-08 | Tôi muốn chọn tag hoạt động thay vì viết ghi chú mỗi lần | Có tag gợi ý đúng danh mục, nhãn dễ hiểu; không hiện slug nội bộ | FR-07 |
| US-09 | Tôi muốn thêm một người ngay lúc lập khoản nợ | Danh sách trống vẫn thêm được và chọn ngay người mới; tiền/ngày/ghi chú không bị mất | FR-08, FR-12 |
| US-10 | Tôi muốn nhận biến động ngân hàng tự động | Chỉ ngân hàng được bật và thông báo mới hợp lệ xuất hiện; trạng thái quyền/dịch vụ rõ | FR-09 |
| US-11 | Tôi muốn phân loại nhanh một biến động | Năm danh mục gợi ý và Khác hoạt động; xác nhận tạo đúng một giao dịch | FR-10 |
| US-12 | Tôi muốn lấy lại thông báo vừa bỏ qua nhầm | Bấm Hoàn tác trước deadline 3 giây thì mục trở lại; restart không làm sai deadline | FR-11 |
| US-13 | Tôi muốn ghi khoản đã cho vay từ hôm qua | Chọn hôm qua, người vay và số tiền; tài khoản có thể trống; cả nợ và sổ đều ghi hôm qua | FR-12 |
| US-14 | Tôi muốn quản lý cả khoản tôi đi vay | Vay nợ vào thu nhập; Trả nợ vào chi tiêu và gắn đúng khoản vay | FR-12 |
| US-15 | Tôi muốn ghi nhiều lần thu/trả rồi tự đánh dấu xong | Lịch sử đầy đủ, cho trả vượt gốc, dư có thể âm; không tự hoàn tất | FR-13 |
| US-16 | Tôi muốn sửa khoản công nợ sau khi tạo | Gốc/ngày/người/ghi chú/hạn được cập nhật theo quyền; khoản và giao dịch liên kết khớp | FR-13 |
| US-17 | Tôi muốn biết vốn đầu tư, tiền về và chênh lệch | Tiền về ghi cả gốc+lãi; báo cáo riêng không mất dữ liệu; dòng tiền vẫn vào tổng thu/chi | FR-14 |
| US-18 | Tôi muốn đánh dấu khoản mình trả cho cả nhóm | Chi tiêu giữ danh mục hoạt động, có Mua chung; có thể bật theo dõi bill và nhập tổng số người và số người đã trả (mặc định đã trả 1 là bạn) | FR-15 |
| US-19 | Tôi muốn ghi người khác chuyển lại phần share bill | Thu nhập → Nhận share bill → tag tên danh mục Chi tiêu; bật thanh gạt, chọn bill đang chờ và số người trong lần nhận (mặc định 1, có −/+), kể cả khi phân loại tiền vào ngân hàng; không tự tạo khoản nợ | FR-15 |
| US-20 | Tôi muốn lưu lời nhắc/ghi chú và ghim mục quan trọng | Nội dung, trạng thái ghim, mốc nhắc nhở và liên kết được lưu/đọc lại đúng | FR-16 |
| US-21 | Tôi muốn xem lịch tháng giống cách đọc Samsung Calendar | Thứ Hai đầu tuần, không lịch âm; có sự kiện theo ngày và mật độ màu | FR-17 |
| US-22 | Tôi muốn xem lịch/biến động từ màn hình chính | Widget đúng kích thước, số chờ đúng, mở đúng tab/ngày và cùng lựa chọn lịch | FR-18 |
| US-23 | Tôi muốn app vẫn giữ những gì vừa nhập lúc mất mạng | Dữ liệu local/outbox còn sau restart; có mạng thì retry an toàn và không nhân đôi | FR-20 |

| US-24 | Tôi muốn biết bill nào còn chờ nhóm trả tiền | Cài đặt → Share Bill chia Đang chờ nhận/Đã hoàn tất; xem tổng tiền, tiến độ, lịch sử và hoàn tất thủ công | FR-15, FR-19 |

| US-25 | Khi bộ đọc ngân hàng mất kết nối, tôi muốn thử khôi phục ngay trong app | Bấm Debug, nhận kết quả kiểm tra/khôi phục có xác nhận; không xóa dữ liệu hay tự bật quyền; báo rõ nếu chưa khôi phục được | FR-09, FR-19 |

## Kịch bản quan trọng

### US-13 — Ghi khoản cho vay từ hôm qua

- **Given:** hôm qua tôi cho một người vay tiền mặt, hôm nay mới nhập app.
- **When:** mở Công nợ, tạo Cho vay, chọn người, nhập 1,200,000 VND, chọn ngày hôm qua và bỏ trống tài khoản thanh toán.
- **Then:** khoản nợ lưu được; ngày khoản nợ và giao dịch chi liên kết cùng là hôm qua; tổng/biểu đồ của kỳ tương ứng cộng khoản chi một lần. Thời điểm tạo bản ghi vẫn là hôm nay.

### US-15 — Trả vượt gốc

- **Given:** một khoản nợ còn 1,000,000 VND.
- **When:** ghi thu/trả 1,100,000 VND vào đúng khoản.
- **Then:** lưu được; dư còn lại -100,000 VND, lịch sử giữ đúng số; khoản chưa tự chuyển sang Đã hoàn tất. Hoàn tất thủ công không phát sinh một giao dịch cân bằng.

### US-18/19 — Mua chung và nhận share bill

- **Given:** tôi thanh toán 500,000 VND tiền ăn cho cả nhóm.
- **When:** ghi Chi tiêu/Ăn uống, bật Chia bill với nhóm và nhập tổng 5 người; sau đó ghi 200,000 VND tại Thu nhập/Nhận share bill/Ăn uống.
- **Then:** sổ giữ hai giao dịch thực tế; nếu bill có tổng 5 người thì tổng chi tăng 300,000 và tổng thu không tăng do nhận share bill. Không xóa khoản gốc hoặc tạo Công nợ.

### US-24 — Theo dõi bill trả hộ và chỉnh sửa

- **Given:** tôi trả hộ 600,000 VND và chờ hai người chuyển lại tiền.
- **When:** tạo Chi tiêu, bật Chia bill với nhóm, chọn tổng 3 người và giữ Đã trả = 1 là bạn; sau đó ghi hai lần Thu nhập/Nhận share bill, mỗi lần 300,000 VND và chọn cùng bill.
- **Then:** bill có hai lần nhận và tiến độ 3/3, tự chuyển Đã hoàn tất. Tổng chi là 0 VND (600,000 − 300,000 − 300,000) và tổng thu không tăng do hai lần nhận lại; không tự tạo Công nợ. Có thể dùng Hoàn tất sớm mà không tạo thêm thu nhập. Nếu một lần chuyển trả hộ hai người thì chọn 2 và tiến độ tăng 2; sửa lần nhận này không đếm thêm một lần.

### US-11 — Retry phân loại

- **Given:** giao dịch đã lưu local nhưng việc đóng thông báo native hoặc đồng bộ bị lỗi.
- **When:** người dùng retry.
- **Then:** tiếp tục hoàn tất xử lý thông báo, không tạo một giao dịch/nợ/lần trả thứ hai.

### US-12 — Undo qua restart

- **Given:** vừa bỏ qua một thông báo và deadline hoàn tác chưa hết.
- **When:** mở lại app và bấm Hoàn tác trước deadline thực tế.
- **Then:** thông báo quay lại, widget/badge thống nhất. Restart không cấp thêm một cửa sổ 3 giây mới.
