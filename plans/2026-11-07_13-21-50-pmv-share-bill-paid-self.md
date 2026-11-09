---
created_at: "2026-11-07T13:21:50+07:00"
updated_at: "2026-11-07T13:27:10+07:00"
timezone: Asia/Ho_Chi_Minh
status: completed
---

# Share Bill tính người trả hộ trong tiến độ

Tổng số người gồm chủ bill. Đã trả mặc định 1 (chủ bill), chỉnh khi tạo/sửa, giữ tổng 5 và 3 của hai bill hiện có. Tiến độ bằng số đã trả ban đầu cộng số người trong các lần nhận. Không tạo thu nhập giả để ghi phần của chủ bill.

1. Test số đã trả ban đầu, sửa và cộng/xóa lần nhận.
2. Service, UI thêm trường số người đã trả, giữ liên kết.
3. Migration mới thêm số người đã trả ban đầu, tương thích outbox cũ; cập nhật đúng hai bill đã được người dùng xác nhận.
4. Cập nhật SRS, test/analyze, DB cô lập, build/cài A54 và kiểm tra đồng bộ; không tạo giao dịch thử thật.

## Kiểm chứng

125 Flutter tests pass; analyze sạch. Migration 014 và tương thích outbox cũ pass trên PostgreSQL cô lập; đã áp dụng cloud. Cập nhật đúng hai bill theo xác nhận người dùng thành 1/5, 1/3, không đổi ledger. Build/cài A54 thành công; kiểm tra danh sách hiện 1/5 và 1/3, form Sửa hiển thị Tổng 5 và Đã trả 1. Không lưu thay đổi form trên máy thật.
