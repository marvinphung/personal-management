# SRS — Yêu cầu phi chức năng và tiêu chí nghiệm thu

Đây là **điều kiện chấp nhận sản phẩm**, không phải kết quả chạy kiểm thử của một phiên triển khai. Kết quả thực thi/ảnh/log phải lưu ngoài `docs/`.

## Phi chức năng

| Mã | Yêu cầu | Điều kiện chấp nhận |
|---|---|---|
| NFR-01 | Thiết bị đích | Hoạt động trên Samsung Galaxy A54, phù hợp Android/One UI; không biến thành dự án triển khai iOS/desktop mới |
| NFR-02 | Dễ thao tác | Bốn tab icon-only có nhãn hỗ trợ tiếp cận, vùng chạm chính khoảng tối thiểu 48dp; tiếp cận được thao tác Lưu khi bàn phím mở |
| NFR-03 | Hiển thị | Theme sáng/tối nhất quán, số tiền tabular, không tràn ở khổ A54 và khi phóng chữ 130%; số âm có dấu âm |
| NFR-04 | Tương phản | Chữ nội dung nhỏ mục tiêu ít nhất 4.5:1; nhãn lịch phải đọc được cả ở ngày tô đậm/chip sự kiện màu sáng |
| NFR-05 | Chính xác tiền | Không mất số 0, sai đơn vị hoặc sai số vì float; định dạng nhập và lưu giá trị đúng với tiền tệ |
| NFR-06 | Bền vững/offline | Thay đổi và outbox không mất qua restart; retry an toàn, không tạo trùng bản ghi hoặc liên kết |
| NFR-07 | Bảo mật/quyền | Chủ dữ liệu được phân tách; không nhúng secret quản trị vào client; lịch chỉ đọc, quyền Android hiển thị đúng trạng thái |
| NFR-08 | Bảo toàn dữ liệu | Cập nhật app bằng cùng signing identity; không reset/gỡ app hoặc xóa dữ liệu để làm cho kiểm tra qua |
| NFR-09 | Phản hồi lỗi | Thiếu trường/quyền/mạng phải có phản hồi, giữ dữ liệu form và cho retry phần được hỗ trợ; không báo thành công giả |
| NFR-10 | Tài liệu hiện hành | SRS nhất quán với quyết định được chốt; không lẫn plan, prompt hoặc báo cáo thực thi trong `docs/` |

## Ma trận nghiệm thu chức năng

| Mã | Kịch bản | Điều kiện đạt | FR/Story |
|---|---|---|---|
| AC-01 | Đăng nhập/đổi chủ | Không lẫn dữ liệu; lựa chọn ngôn ngữ/phiên đúng ngữ cảnh | FR-01/US-01 |
| AC-02 | Bốn tab và chức năng phụ | Icon-only nhưng có semantics; mở Công nợ/Đầu tư/Lịch/Ghi chú từ Cài đặt được | FR-02/US-02 |
| AC-03 | Tổng quan | Thu/chi/chênh lệch/biểu đồ khớp ledger cùng kỳ/tiền tệ; số âm có dấu | FR-03/US-03 |
| AC-04 | Nhập tiền | 1000000 → 1,000,000; 4321 → 4,321; sửa/xóa/dán và lưu không đổi giá trị | FR-04/US-05 |
| AC-05 | Giao dịch thủ công quá khứ | Ngày được chọn được lưu/nhóm đúng kỳ, khác với thời điểm tạo bản ghi | FR-04/US-04 |
| AC-06 | Tìm/lọc/sửa | Tìm ra đúng bản ghi, sửa trường được phép và cập nhật thống kê | FR-05/US-06 |
| AC-07 | Transfer | Hai tài khoản phù hợp, không cộng vào thu/chi chung, không tạo trùng | FR-06/US-07 |
| AC-08 | Catalog/tag | Nhãn đọc được, liên kết đúng danh mục, dữ liệu lưu trữ không làm mất lịch sử | FR-07/US-08 |
| AC-09 | Danh sách người rỗng | Thêm inline rồi tự chọn được, tiền/ngày/ghi chú form cha còn nguyên | FR-08/US-09 |
| AC-10 | Nguồn ngân hàng | Quyền/capture/connected phản ánh đúng, chỉ tiếp nhận thông báo hợp lệ theo nguồn bật | FR-09/US-10 |
| AC-11 | Classify/retry | Năm gợi ý + Khác đúng hướng; retry chỉ có một giao dịch và đúng nguồn/liên kết | FR-10/US-11 |
| AC-12 | Undo | Hoàn tác trong 3 giây, restart không gia hạn, badge/widget/list thống nhất; native lỗi không mất khả năng retry | FR-11/US-12 |
| AC-13 | Cho vay hôm qua | Chọn ngày hôm qua, để trống tài khoản và lưu; ngày nợ/ledger khớp, tổng tính một lần | FR-12/US-13 |
| AC-14 | Vay nợ/Trả nợ | Ghi đúng hướng thu/chi và chọn đúng khoản vay; lịch sử cập nhật | FR-12/US-14 |
| AC-15 | Trả vượt/Hoàn tất | Dư âm được giữ, không tự hoàn tất; nút Hoàn tất giữ lịch sử, không sinh cân bằng | FR-13/US-15 |
| AC-16 | Sửa công nợ | Ngày/gốc liên kết khớp, không mất thanh toán/trạng thái, bank source vẫn read-only | FR-13/US-16 |
| AC-17 | Đầu tư | Vốn, toàn bộ tiền về và chênh lệch đúng với bộ lọc cả hai chiều; vẫn vào tổng chung | FR-14/US-17 |
| AC-18 | Share bill | Mua chung ở mọi danh mục chi; Nhận share bill có tag tương ứng; không tự tạo nợ/net | FR-15/US-18–19 |
| AC-19 | Ghi chú | Nội dung, ghim, mốc nhắc nhở/liên kết lưu và đọc lại đúng | FR-16/US-20 |
| AC-20 | Calendar | Tháng sáu tuần không mất ngày cuối; ngày được chọn/sự kiện lặp/cả ngày/nhiều ngày hiển thị đúng | FR-17/US-21 |
| AC-21 | Widget | Biến động 2×2 và Lịch 4×2 hiện được trên One UI; mở đúng tab/ngày; không quyền/rỗng không crash | FR-18/US-22 |
| AC-22 | Offline/restart | Local/outbox còn nguyên và retry không nhân đôi khi có mạng | FR-20/US-23 |

## Phân biệt các lớp xác minh

Test nghiệp vụ/widget, analyze, build APK và nghiệm thu A54 là các lớp khác nhau. Build thành công không chứng minh widget trên launcher hoặc luồng bàn phím đã được kiểm tra thực tế. Khi có thay đổi giao diện, cần kiểm tra phần bị ảnh hưởng trên thiết bị được giao; khi chưa có thiết bị, ghi đúng phần chưa kiểm tra ngoài SRS.
