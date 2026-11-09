---
created_at: "2026-11-07T18:58:06+07:00"
updated_at: "2026-11-07T18:58:06+07:00"
timezone: Asia/Ho_Chi_Minh
status: in_progress
---

# Chi Share Bill theo tiền thực nhận và cài lại app

Thay công thức chia đều bằng tổng chi gốc trừ tổng payment chưa xóa của đúng bill. Số người chỉ ảnh hưởng tiến độ. Giữ số tiền nguồn và số dư theo giao dịch thật; nhận lại không vào tổng thu. Receipt khác tháng vẫn giảm chi bill trong kỳ giao dịch chi; số âm giữ nguyên nếu nhận vượt.

Kiểm chứng: test nghiệp vụ/biểu đồ/số dư, analyze và build wrapper; cài lại A54 sau khi người dùng đã xóa app. Không tạo dữ liệu thử thật hoặc reset DB. Đăng nhập lại để tải dữ liệu cloud nếu phiên cũ bị xóa.
