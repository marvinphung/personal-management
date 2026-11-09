# Debug khôi phục bộ đọc ngân hàng

Nút Debug nằm ở AppBar Cài đặt Ngân hàng, có trong bản thông thường. Flutter chờ kết quả native, hiển thị cả khi tải settings bị lỗi.

Native `ListenerRecovery` kiểm tra owner/capture/Notification Access. Nếu đang kết nối thì chỉ báo trạng thái. Nếu mất kết nối, requestRebind; sau 3 giây chưa có callback thì thử disable/restore riêng component của PMV, giữ nguyên trạng thái ban đầu, rồi requestRebind. Poll callback đến hạn 10 giây, chống bấm lặp. Không có callback thì unresolved, không giả connected.

Marker reset lưu trong preferences `listener_recovery`, tách khỏi preferences owner. `ListenerConnection.ensureBound` khôi phục marker trước khi xét owner/capture: mở lại app sau process death hoặc logout vẫn phục hồi component. Marker chỉ lưu trạng thái component, không chứa dữ liệu notification. Không xóa draft, đổi permission/capture, gán tài khoản hay sửa ledger.

Giới hạn: A54 từng kẹt ở ManagedServices “already binding” dù binder null. Chưa tái hiện trạng thái này sau reboot để chứng minh Debug khôi phục được trên firmware thật; component reset là lần thử có giới hạn, không bảo đảm thay được reboot.

Kiểm chứng tự động: 132 Flutter tests pass, analyze sạch, 9 native tests (ListenerRecoveryTest + ListenerTest) pass. Bao phủ unresolved không báo thành công giả, thiếu quyền/capture, callback thật, đổi owner, khôi phục marker sau cleanup và reconnect/dedup cũ. Build debug qua wrapper thành công.

Tham chiếu API: [NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService), [PackageManager](https://developer.android.com/reference/android/content/pm/PackageManager).
