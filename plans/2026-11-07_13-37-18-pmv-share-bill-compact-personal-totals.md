---
created_at: "2026-11-07T13:37:18+07:00"
updated_at: "2026-11-07T13:40:47+07:00"
timezone: Asia/Ho_Chi_Minh
status: completed
---

# Share Bill: form gọn và thống kê phần chi cá nhân

Yêu cầu: bật nhận Share Bill thì ẩn Danh mục/Tag, thanh gạt và chọn bill ở phần đầu form Thu nhập/phân loại ngân hàng. Tổng chi = tổng bill / tổng người; nhận lại Share Bill không cộng tổng thu. Giữ dòng tiền gốc cho số dư và lịch sử, áp dụng thống nhất biểu đồ.

1. Test ẩn/hiện form, báo cáo phần chi cá nhân, hoàn tiền không thành thu nhập và số dư vẫn theo tiền thật.
2. Dùng projection chỉ đọc cho báo cáo; không ghi đè số tiền giao dịch/cloud.
3. Cập nhật SRS thay quy tắc cũ, chạy test/analyze và build đúng wrapper.
4. Cài đè A54, kiểm tra form và đồng bộ, không tạo giao dịch thật.

## Kết quả

128 Flutter tests pass, analyze sạch, build/cài A54 thành công. Kiểm tra máy thật: bật nhận Share Bill thì Danh mục/Tag không còn trong cây UI; picker ở phần đầu form (không cần cuộn để chọn). Test form ngân hàng xác nhận ẩn/hiện cùng quy tắc. Test báo cáo xác nhận chi cá nhân, tiền nhận không vào thu, số dư vẫn theo tiền thực. App Đã đồng bộ. Không tạo giao dịch thử thật, không cần migration mới.
