# Rà soát Share Bill và độ phủ SRS

Phạm vi: đọc mã nguồn hiện tại và đối chiếu SRS. Không thay đổi nghiệp vụ, build/cài app hoặc tác động DB trong lượt rà soát này. Đây là phát hiện qua đọc mã, chưa phải kết quả tái hiện trên thiết bị.

## Phần đã có

- Cài đặt có mục Share Bill; danh sách chia nhóm chờ nhận/hoàn tất theo tiền tệ.
- Form chi thủ công ngoài Công nợ cho bật theo dõi bill và nhập số người sẽ trả lại.
- Form thu Nhận share bill có bộ chọn bill đang active; service lưu lần nhận và giao dịch thu cùng outbox.
- Service tăng tiến độ, tự hoàn tất khi đủ lượt; chi tiết có Hoàn tất thủ công và xóa lần nhận.
- Cloud có migration 012 cho bill/payment, RLS cùng chủ và mở rộng allowlist RPC đồng bộ.

## Điểm cần sửa/kiểm chứng tiếp

1. **Số Còn lại không dùng tiền thực nhận.** `share_bill_screen.dart`, `_ShareBillCard.build`, tính `total ~/ numPeople` rồi lấy `total - perPerson * numPaid`. Ví dụ bill 600,000, dự kiến 2 người, đã nhận 100,000 thì UI suy ra còn 300,000 thay vì phản ánh số thực nhận 100,000. Lịch sử có `payment.amount` nhưng card chưa dùng để tính.
2. **Bộ chọn và service chưa chặn khác tiền tệ.** `transaction_form.dart` lọc bill theo active/deleted nhưng chưa theo currency; `ShareBillService.saveIncomeWithShareBillPayment` chưa so tiền tệ giao dịch với bill. Có thể cộng một lượt USD vào bill VND rồi hiển thị số payment theo tiền tệ bill.
3. **Chỉnh sửa giao dịch liên kết chưa phục hồi trạng thái bill.** Form khởi tạo `_shareBillEnabled=false`, `_selectedShareBillId=null` và chưa nạp lại liên kết khi sửa. Lưu như giao dịch thường có thể đổi ledger mà không đổi bill/payment. Nếu chọn lại bill khi sửa thu, service dùng ID payment ổn định nhưng luôn `num_paid + 1`, gây đếm thêm lượt cho cùng giao dịch. Nếu bật lại chia bill khi sửa chi, service tái tạo bill từ mặc định `num_paid=0`, `status=active`.
4. **Tiến độ đang đếm lượt, không xác minh người.** Không có `person_id` ở payment; một người trả nhiều lần vẫn được đếm nhiều lượt. Cần giữ rõ khác biệt giữa nhãn UI “người đã trả” và dữ liệu thực tế trước khi mở rộng nghiệp vụ.

## Cập nhật tài liệu

SRS trước rà soát chỉ có mô tả tag Mua chung/Nhận share bill và phần mô hình hai bảng. Đã bổ sung tính năng FR-15, story US-24, luồng FL-09, quy tắc BR-28–31 và nghiệm thu AC-23–25; cập nhật tổng quan/điểm truy cập. SRS là yêu cầu chấp nhận, không chứng nhận các điểm chưa khớp bên trên đã được sửa.

Kiểm chứng lượt này: đối chiếu source, kiểm tra liên kết Markdown và `git diff --check`. Test/analyze/build/device: NOT RUN (chỉ thay đổi tài liệu).

## Sau triển khai yêu cầu sửa Share Bill

Các điểm 1–3 đã được sửa trong service/form: tiền thực nhận lấy từ payment, kiểm tra cùng tiền tệ, khôi phục liên kết khi sửa và tính lại tiến độ thay vì cộng thêm. Tiến độ được mở rộng thành tổng `people_count` (mặc định 1) để một lần chuyển có thể trả hộ nhiều người; vẫn không xác minh danh tính từng người. Mặc định tạo bill là 1 người. Có nút Sửa Share Bill trong chi tiết và mở sửa lần nhận qua lịch sử. Cả form Thu nhập và phân loại tiền vào đều có thanh gạt Nhận Share Bill, bộ chọn bill và −/+.

Migration 013 thêm `people_count`, `manual_completed_at` và tương thích payload outbox cũ; đã kiểm tra trên PostgreSQL cô lập và áp dụng cloud. Giữ hoàn tất thủ công khi sửa/xóa lần nhận; bill tự hoàn tất có thể trở lại đang chờ khi tiến độ giảm.

Kiểm chứng bổ sung: full Flutter suite cuối cùng 124 tests pass, gồm mặc định 1 và tăng số người dự kiến; analyze không có issue; build debug qua wrapper và cài đè A54 thành công. Trên A54 kiểm tra form Chi tiêu mặc định 1, thanh gạt Thu nhập hiện bộ chọn bill và nút + tăng 1→2, trạng thái Đã đồng bộ. Không lưu giao dịch thử trên DB thật. Luồng ngân hàng có test retry nghiệp vụ; chưa xác nhận một draft thật để thử UI.

## Điều chỉnh đã chốt: chủ bill là người đã trả đầu tiên

Tổng số người gồm chủ bill. Trường Đã trả mặc định 1, sửa được; service lưu `initial_paid_people`, cộng người từ receipt để tính tổng và không cho giảm dưới phần chủ bill + receipt còn hiệu lực. Migration 014 bổ sung trường, xử lý payload cũ. Theo xác nhận trực tiếp người dùng, hai bill hiện có giữ tổng 5 và 3, đặt Đã trả về 1; không sửa ledger. Nhãn Chi − nhận lại chỉ mô tả chênh lệch dòng tiền, không coi phần của chủ bill là khoản Thu nhập.

Kiểm chứng cuối: 125 tests pass, analyze sạch; migration/test payload cũ pass cô lập; build và cài đè thành công. A54 hiển thị 1/5, 1/3, mở sửa bill 5 người thấy Đã trả = 1. Đóng form không lưu.

## Yêu cầu tiếp theo: form gọn và báo cáo phần chi cá nhân

Nhận Share Bill chuyển lên đầu form Thu nhập; bật thì ẩn Danh mục và Tag, vẫn gán Nhận share bill tự động. Form phân loại tiền vào dùng cùng quy tắc. Tắt thì hiện lại phân loại thường.

`Ledger.reportingRows` chiếu số tiền chỉ phục vụ báo cáo: chi bill chia tổng người, làm tròn đơn vị nhỏ nhất; loại thu liên kết bill hoặc danh mục Nhận share bill khỏi tổng thu. Tổng quan, biểu đồ ngày/danh mục/tag và tổng thu/chi chi tiết tài khoản dùng cùng projection. Số dư/lịch sử dùng số gốc; không ghi projection vào DB/outbox. Tag Mua chung không có bill vẫn là chi thường. Không cần migration mới.

Kiểm chứng: 128 tests pass; analyze sạch; build/cài A54 thành công. UI máy thật không còn Danh mục/Tag khi bật Share Bill, picker gần đầu form; app Đã đồng bộ. Không lưu giao dịch thử thật.
