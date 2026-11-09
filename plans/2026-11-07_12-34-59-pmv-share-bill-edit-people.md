---
created_at: "2026-11-07T12:34:59+07:00"
updated_at: "2026-11-07T12:50:05+07:00"
timezone: Asia/Ho_Chi_Minh
status: completed
---

# Share Bill: chỉnh sửa và số người nhận trả hộ

Mục tiêu: mặc định 1 người khi tạo bill và nhận tiền; chọn bill chưa hoàn tất qua thanh gạt ở thu nhập thủ công và phân loại ngân hàng; tăng/giảm số người mỗi lần nhận; sửa bill và lần nhận không sai tiến độ.

1. Test nghiệp vụ cho tiền thực nhận, cùng tiền tệ, sửa/retry và people_count.
2. Service giữ ID, tính lại tiến độ từ payment, phân biệt hoàn tất thủ công.
3. UI nhập/sửa và phân loại ngân hàng dùng cùng control, lọc đúng tiền tệ, khôi phục liên kết khi sửa.
4. Migration mới bổ sung số người mỗi payment và dấu hoàn tất thủ công; giữ dữ liệu cũ mặc định 1.
5. Cập nhật SRS; chạy test/analyze, kiểm tra migration cô lập, build/cài đúng chữ ký và kiểm tra màn hình nếu A54 sẵn sàng. Không tạo giao dịch thật khi kiểm thử.

## Kết quả

Đã triển khai và cập nhật SRS. Test nghiệp vụ/widget pass; migration 013 và tương thích payload cũ đã kiểm tra cô lập rồi áp dụng cloud. Build/cài đè A54 thành công, kiểm tra mặc định 1, thanh gạt Thu nhập, bộ chọn bill và + tăng 2; app Đã đồng bộ. Không lưu giao dịch thử vào dữ liệu thật. Báo cáo chi tiết tại quan-ly-pmv/reference/engineering/share-bill-review-2026-11-07.md.
