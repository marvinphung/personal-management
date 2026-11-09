# Tạo Share Bill khi phân loại biến động tiền ra

Nguyên nhân thiếu control: PmvClassifyForm trước đó chỉ render ShareBillControls cho income; BankConfirmation mới hỗ trợ liên kết payment thu, chưa có nhánh tạo bill chi.

Đã mở rộng form expense ngoài Công nợ: bật chia bill, tổng số người và đã trả ban đầu; giữ danh mục/tag. Income tiếp tục ẩn danh mục/tag khi bật nhận Share Bill. Chuyển sang danh mục Công nợ sẽ tắt chia bill. Chọn tag được kiểm tra cùng category để tránh trùng slug giữa các danh mục.

BankConfirmation thêm nhánh createShareBill gọi service hiện có với import key ổn định. Nguồn ngân hàng giữ read-only; transaction, bill, tags và outbox nguyên tử. Không cần migration mới.

Kiểm chứng: 134 Flutter tests pass, analyze sạch, build/cài A54 thành công. Test service kiểm tra retry không trùng, source được giữ; test widget lưu fake bank expense thành bill 2 người, đã trả 1 và đúng scoped tag. Có thực hiện một phân loại thật theo chỉ định trực tiếp của người dùng, kiểm tra cloud read-only xác nhận đúng một transaction/bill và native draft được đóng; không lưu thông tin giao dịch thật vào tài liệu này.
