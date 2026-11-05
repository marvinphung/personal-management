# SRS — Danh mục và tag mặc định

Bộ danh mục đã chốt gồm **12 danh mục Chi tiêu và 8 danh mục Thu nhập**. Người dùng có thể có dữ liệu phân loại bổ sung; không dùng quá trình cập nhật bộ mặc định để xóa giao dịch hoặc tag cá nhân.

## Chi tiêu

Mỗi danh mục bên dưới có thêm tag **Mua chung**. Trong Công nợ, đây là marker bổ sung bên cạnh hành động bắt buộc.

| Danh mục | Tag gợi ý cơ sở |
|---|---|
| Ăn uống | Ăn sáng, Ăn trưa, Ăn tối, Ăn khuya, Ăn vặt, Cà phê, Nước uống, Đồ uống khác, Đi chợ, Siêu thị thực phẩm, Đặt đồ ăn, Nhà hàng, Nhậu, Tiệc/tụ tập |
| Đi lại | Đổ xăng, Xe ôm, Taxi, Gửi xe, Sửa xe |
| Mua sắm | Quần áo, Giày dép, Phụ kiện, Đồ cá nhân, Đồ gia dụng, Đồ điện tử, Đồ dùng công việc |
| Nhà & hóa đơn | Tiền nhà, Tiền Điện + nước, Internet, Điện thoại/4G/5G, Phí dịch vụ |
| Giải trí | Xem phim, Game, Nghe nhạc, Đăng ký dịch vụ, Đi chơi, Sự kiện/biểu diễn |
| Sức khỏe | Khám bệnh, Thuốc, Thể thao, Bảo hiểm, Thực phẩm |
| Gia đình & quà tặng | Biếu bố mẹ, Hỗ trợ người thân, Quà tặng, Sinh nhật, Đám cưới, Đám tang, Lễ/Tết |
| Du lịch | Di chuyển, Lưu trú, Ăn uống, Tham quan, Mua quà, Tour |
| Chi khác | Phí ngân hàng, Phí giấy tờ, Từ thiện, Chi chưa phân loại |
| Trả sau | Shopee, TikTok, Thẻ tín dụng, Khác |
| Công nợ | Cho vay, Trả nợ |
| Đầu tư | Chứng khoán, Quỹ đầu tư, Crypto, Vàng, Tiết kiệm, Góp vốn, Khác |

## Thu nhập

| Danh mục | Tag gợi ý cơ sở |
|---|---|
| Lương | Lương chính, Phụ cấp, Làm thêm giờ |
| Thưởng | Thưởng tháng, Thưởng quý, Thưởng Tết, Thưởng dự án, Thưởng khác |
| Làm thêm | Việc ngoài, Freelance, Gia sư |
| Được tặng | Gia đình, Bạn bè, Người yêu, Mừng tuổi, Quà bằng tiền |
| Thu khác | Hoàn tiền, Lãi tiết kiệm, Bán đồ cá nhân, Khác |
| Công nợ | Thu nợ, Vay nợ |
| Đầu tư | Chứng khoán, Quỹ đầu tư, Crypto, Vàng, Tiết kiệm, Góp vốn, Khác |
| Nhận share bill | Ăn uống, Đi lại, Mua sắm, Nhà & hóa đơn, Giải trí, Sức khỏe, Gia đình & quà tặng, Du lịch, Chi khác, Trả sau, Công nợ, Đầu tư |

## Quy tắc của bộ danh mục

- Trà sữa không nằm trong gợi ý Ăn uống đã chốt; có Nước uống.
- Đi lại chỉ có các gợi ý cơ sở Đổ xăng, Xe ôm, Taxi, Gửi xe, Sửa xe; Mua chung là tag bổ sung chung.
- Nhà & hóa đơn có Tiền Điện + nước; không thêm lại Gas/Sửa chữa nhà vào bộ mặc định.
- Sức khỏe chỉ có các gợi ý cơ sở Khám bệnh, Thuốc, Thể thao, Bảo hiểm, Thực phẩm.
- Việc ngoài/Freelance/Gia sư thuộc Làm thêm, không đưa sang Lương.
- Trả sau dùng để ghi nhận hóa đơn trả sau; không tạo một module trả góp hoặc tự lập lịch kỳ trả mới.
- Công nợ và Đầu tư có bản ghi danh mục riêng ở hai hướng thu/chi dù nhãn giống nhau.
- Mua chung có bản ghi/tag ID riêng cho từng danh mục chi. Nhận share bill dùng nhãn các danh mục chi làm tag, gồm cả Công nợ và Đầu tư.
- Các danh mục chi tùy chỉnh đang hoạt động cũng cần được phản ánh vào gợi ý share bill; đổi tên/ẩn mục không được làm sai liên kết lịch sử.
- Tag hiển thị tên tiếng Việt từ display_name hoặc bảng nhãn tương ứng. Slug/ID không phải tên để hiển thị cho người dùng.
- Tag gợi ý hỗ trợ nhập nhanh; ghi chú riêng luôn là tùy chọn đối với giao dịch thông thường.

Chi tiết hạch toán và hành động đặc biệt: [quy tắc nghiệp vụ](business-rules.md).
