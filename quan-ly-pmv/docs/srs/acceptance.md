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
| AC-18 | Mua chung | Mua chung ở mọi danh mục chi; Nhận share bill có tag tương ứng; không tự tạo nợ/net | FR-15/US-18–19 |
| AC-23 | Tạo bill và nhận tiền | Bật theo dõi khi tạo chi, mặc định 1 người, −/+ không xuống dưới 1; bật nhận Share Bill ở Thu nhập/phân loại ngân hàng chọn đúng bill chưa hoàn tất cùng tiền tệ; một lần nhận có thể trả hộ nhiều người; bill/payment/giao dịch/outbox nguyên tử; retry/sửa không tăng trùng tiến độ | FR-15/US-18–19, US-24 |
| AC-24 | Tiến độ và hoàn tất bill | Hiện nhóm chờ/hoàn tất, tiến độ và lịch sử; tiến độ bằng số đã trả ban đầu cộng số người các lần nhận, không đếm số giao dịch; trường Đã trả mặc định 1 là chủ bill và chỉnh được khi tạo/sửa; đủ người thì tự hoàn tất; sửa bill/lần nhận giữ liên kết và tính lại tiến độ; Hoàn tất thủ công không sinh thu; xóa lần nhận cập nhật dòng thu và tiến độ | FR-15/US-24 |
| AC-25 | Tiền thực nhận và cloud bill | Lần nhận 100,000 rồi 250,000 phải thể hiện thực nhận 350,000, không giả định chia đều; dữ liệu cùng chủ/tiền tệ, cloud hỗ trợ cả hai bảng và retry không trùng | FR-15, FR-20/US-24 |
| AC-19 | Ghi chú | Nội dung, ghim, mốc nhắc nhở/liên kết lưu và đọc lại đúng | FR-16/US-20 |
| AC-20 | Calendar | Tháng sáu tuần không mất ngày cuối; ngày được chọn/sự kiện lặp/cả ngày/nhiều ngày hiển thị đúng | FR-17/US-21 |
| AC-21 | Widget | Biến động 2×2 và Lịch 4×2 hiện được trên One UI; mở đúng tab/ngày; không quyền/rỗng không crash | FR-18/US-22 |
| AC-22 | Offline/restart | Local/outbox còn nguyên và retry không nhân đôi khi có mạng | FR-20/US-23 |

## Phân biệt các lớp xác minh

Test nghiệp vụ/widget, analyze, build APK và nghiệm thu A54 là các lớp khác nhau. Build thành công không chứng minh widget trên launcher hoặc luồng bàn phím đã được kiểm tra thực tế. Khi có thay đổi giao diện, cần kiểm tra phần bị ảnh hưởng trên thiết bị được giao; khi chưa có thiết bị, ghi đúng phần chưa kiểm tra ngoài SRS.

## Quy đổi giao dịch ngân hàng USD

Khi phân loại thông báo USD, giữ nguyên số tiền nguồn và ghi sổ VND theo tỷ giá cố định 1 USD = 27,000 VND. Lưu số gốc (cent USD), loại tiền nguồn và tỷ giá trong provenance `bank_source`; số tiền giao dịch dùng VND và tham gia tổng/biểu đồ VND đúng một lần. Tài khoản ghi sổ phải là VND. Form hiển thị số USD gốc và số VND quy đổi; chi tiết giao dịch giữ thông tin nguồn. Ví dụ 22.22 USD = 599,940 VND; 0.01 USD = 270 VND. Không đổi các giao dịch đã xác nhận trước đây; retry không tạo trùng.

## Share Bill gọn và thống kê chi cá nhân

- Bật Nhận Share Bill ở Thu nhập/phân loại ngân hàng: không còn Danh mục, Tags, ô tạo tag; chọn bill/số người ở gần đầu form. Tắt thì phân loại thường xuất hiện trở lại.
- Bill 500,000 VND, 5 người, nhận lại 200,000 VND: tổng chi/biểu đồ ghi 300,000 VND; tổng thu không tăng bởi khoản nhận lại. Ledger vẫn giữ chi 500,000 và thu 200,000; số dư tài khoản giảm thực 300,000 VND. Sửa tổng người thành 4 không đổi số chi; sửa tiền nhận thành 250,000 VND thì chi còn 250,000 VND, không sửa số tiền chi gốc. Xóa lần nhận sẽ tăng lại số chi tương ứng. Nhận khác tháng vẫn cập nhật chi của bill; nhận vượt giữ số âm.

## Debug bộ đọc ngân hàng

- Nút Debug hiển thị trong Cài đặt Ngân hàng trên bản sử dụng bình thường, không chỉ bản phát triển.
- Không quyền, không capture hoặc đổi owner: không thực hiện khôi phục/không tự bật quyền; không báo kết nối thành công.
- Request rebind không có callback: đến hạn phải báo chưa khôi phục được. Callback thật: mới báo đã khôi phục. Dữ liệu tài chính và draft chờ không bị thay đổi.
- Reset riêng component phải khôi phục trạng thái cũ; nếu tiến trình chết giữa các bước, mở lại app phục hồi component từ marker bền vững. Marker này không bị xóa cùng phiên/owner.

## Tạo Share Bill từ biến động Chi tiêu

- Thông báo tiền ra có thanh gạt Chia bill với nhóm. Bật rồi chọn được tổng 2 người, Đã trả mặc định 1, danh mục chi và tag đúng danh mục.
- Xác nhận tạo đúng một giao dịch giữ số tiền/nguồn ngân hàng và một bill liên kết; retry không trùng. Hai tag cùng slug ở hai danh mục phải gắn đúng tag của danh mục đã chọn.
- Tiền ra giữ Danh mục/Tag; nhận Share Bill bên tiền vào vẫn ẩn hai phần này.
