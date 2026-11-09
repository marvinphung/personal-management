---
created_at: "2026-11-09T12:27:44+07:00"
updated_at: "2026-11-09T12:27:44+07:00"
timezone: Asia/Ho_Chi_Minh
status: in_progress
---

# Nút Debug khôi phục bộ đọc ngân hàng

Thêm Debug trong Cài đặt Ngân hàng. Kiểm tra owner, capture, quyền; nếu đã kết nối báo trạng thái. Nếu mất kết nối thử requestRebind rồi reset riêng component khi không có callback; có timeout, chống bấm lặp và phục hồi component nếu tiến trình chết giữa bước reset. Không bật quyền/capture thay người dùng, không sửa/xóa/confirm draft hoặc dữ liệu tài chính. Không hứa luôn thay được reboot khi hệ thống bị kẹt.

1. Test native chặn sai owner/quyền/capture, không báo thành công giả, timeout và khôi phục component; test UI Debug.
2. Native recovery + bridge có xác nhận trạng thái, adapter Flutter và nút Debug hiển thị kết quả.
3. Cập nhật SRS, chạy test/analyze và build wrapper.
4. Cài/kiểm tra A54 nếu thiết bị sẵn sàng; thử giao dịch mới chỉ sau khi người dùng chuyển tiền theo yêu cầu, không tạo giao dịch thật tự động.
