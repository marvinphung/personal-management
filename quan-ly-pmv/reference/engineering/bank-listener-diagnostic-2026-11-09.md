# Chẩn đoán bộ đọc thông báo ngân hàng PMV

Thời điểm: 2026-11-09T12:16:53+07:00.

## Bằng chứng trên A54

- Notification Access của đúng component PMV đã được cấp; capture bật, owner đã cấu hình.
- Process PMV đang chạy, nhưng ServiceRecord của NotificationListener có app=null, binder=null, requested=false, hasBound=false.
- Lịch sử tiến trình có LOW_MEMORY, REMOVE TASK và Chimera kills. Đây là bối cảnh trước lỗi, chưa chứng minh lần kill nào gây kẹt.
- Mở app/requestRebind và tắt/bật lại quyền đã có chưa sửa được kết nối. NotificationManager ghi Not registering ... is already binding trong khi binder chưa có.
- Chưa xác định lỗi parser hay định dạng thông báo mới vì chưa có callback ngân hàng mới được quan sát.

## Tình trạng xử lý

Đã yêu cầu người dùng khởi động lại A54 rồi mở khóa, trước khi chuyển tiền thử. Cần xác minh listener live/connected sau reboot; sau đó mới nhờ người dùng tạo thông báo ngân hàng mới và đối chiếu lastBankAt/outcome/pending. Không xác nhận/bỏ qua thông báo thật hoặc sửa giao dịch.

Không sửa code, reset dữ liệu, đổi signing hay push trong lượt chẩn đoán này. Quyền notification đã được trả lại trạng thái được cấp sau lần thử reconnect. Thử đổi trạng thái component bằng shell bị hệ điều hành từ chối, không có thay đổi component nào được áp dụng.
