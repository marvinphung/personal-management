---
created_at: "2026-11-09T16:38:55+07:00"
updated_at: "2026-11-09T16:46:04+07:00"
timezone: Asia/Ho_Chi_Minh
status: completed
---

# Share Bill khi phân loại thông báo tiền ra

Bổ sung bật chia bill trong phân loại expense, nhập tổng người và đã trả mặc định 1; giữ danh mục/tag. Income giữ UI gọn hiện có. Ghi bank transaction + bill + outbox nguyên tử và retry không trùng.

1. Test backend và widget cho bank expense share bill, category/tag đúng và nguồn bất biến.
2. Mở rộng BankConfirmation và PmvClassifyForm; cập nhật SRS.
3. Test/analyze/build/cài A54 đúng signing.
4. Theo ủy quyền trực tiếp của người dùng, phân loại đúng một draft tiền ra được chỉ định thành bill 2 người, danh mục và tag được yêu cầu; xác minh đồng bộ. Không dùng giao dịch thật đó làm test tự động hoặc đưa dữ liệu thật vào Git.

## Kết quả

134 Flutter tests pass; analyze sạch; build và cài A54 thành công. SRS đã bổ sung Share Bill từ thông báo tiền ra, giữ danh mục/tag và phân biệt với nhận Share Bill. Đã thực hiện đúng phân loại được người dùng chỉ định; kiểm tra read-only cloud có một giao dịch liên kết một bill 2 người, đã trả 1, category/tag đúng, giữ nguồn ngân hàng; draft không còn trong danh sách chờ. Không đưa dữ liệu tài chính thật/ảnh/log vào Git.
