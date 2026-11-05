# Prompt chạy và test Android Collector/Admin App

Copy nguyên khối prompt dưới đây cho Codex trên máy đang kết nối với thiết bị
Android. Endpoint dùng dạng punycode để mọi công cụ Android xử lý ổn định; đây
chính là tên miền `api.quản-lý-tao.id.vn`.

```text
Bạn đang làm việc trong repository personal-management và cần build, cài đặt,
chạy rồi kiểm thử Android Collector/Admin App trên một thiết bị Android thật.

Thông tin server:
- App cần chạy: apps/collector_app (không phải apps/user_app)
- Package Android: app.quanlytao.collector
- API_BASE_URL=https://api.xn--qun-l-tao-49a0064f.id.vn/v1
- Health: https://api.xn--qun-l-tao-49a0064f.id.vn/v1/health/ready
- Swagger: https://api.xn--qun-l-tao-49a0064f.id.vn/docs
- Admin username: admin
- Admin password: Admin@123456

Backend chạy trên Mac mini qua Cloudflare Tunnel. Thiết bị không cần cùng Wi-Fi
và không cần Tailscale. Mobile app chỉ gọi HTTPS API; không kết nối trực tiếp
PostgreSQL hoặc NATS. Không dùng nats.quản-lý-tao.id.vn, port 4222, port 8001,
10.0.2.2 hay endpoint Tailscale cũ.

Hãy tự thực hiện toàn bộ công việc sau, không chỉ viết hướng dẫn:

1. Kiểm tra repository và giữ nguyên mọi thay đổi có sẵn. Không reset/checkout
   hoặc xóa thay đổi của người khác.
2. Chạy health endpoint. Chỉ tiếp tục khi HTTP 200 và JSON báo status=ready,
   database=connected, broker=connected.
3. Chạy `flutter doctor -v`, `flutter devices` và `adb devices -l`; xác định đúng
   DEVICE_ID của điện thoại. Nếu ADB chưa được cấp quyền, hướng dẫn tôi xác nhận
   hộp thoại USB debugging rồi tiếp tục.
4. Chạy kiểm tra phù hợp trước khi cài:
   - `cd apps/collector_app && flutter pub get`
   - `flutter analyze`
   - `flutter test`
   - nếu môi trường hỗ trợ, chạy Android Gradle unit tests.
5. Từ thư mục gốc repository, chạy app bằng đúng server public:

   API_BASE_URL=https://api.xn--qun-l-tao-49a0064f.id.vn/v1 \
     python3 tool/flutter_client.py collector run -d DEVICE_ID

   Nếu cần cài APK thay vì flutter run, build với:

   cd apps/collector_app
   flutter build apk --debug \
     --dart-define=API_BASE_URL=https://api.xn--qun-l-tao-49a0064f.id.vn/v1
   adb install -r build/app/outputs/flutter-apk/app-debug.apk

6. Mở app và đăng nhập bằng tài khoản admin ở trên. Xác nhận app nhận đúng role
   admin và hiển thị các tab Trạng thái, Người dùng, Cấu hình ngân hàng và Thiết
   bị.
7. Kiểm tra các luồng không phá hủy dữ liệu:
   - tải danh sách người dùng và thấy user `demo` đang active;
   - mở cấu hình ngân hàng nhưng không ghi đè dữ liệu thật nếu không cần;
   - xem trạng thái collector, epoch và hàng đợi;
   - cấp Notification Access cho app;
   - đặt Battery thành Unrestricted/Không hạn chế;
   - kiểm tra app mở lại được sau khi đưa xuống background.
8. Không purge/xóa user `demo`, không reset database, không xóa JetStream và
   không đăng nhập collector trên nhiều máy nếu việc đó làm đổi collector epoch.
9. Nếu gặp lỗi source/build/config Android, tự chẩn đoán và sửa trong phạm vi
   repository, sau đó chạy lại analyze/test/build. Không hardcode URL hoặc bí mật
   vào source. API URL phải được truyền qua `--dart-define`.
10. Khi xong, báo rõ: thiết bị đã dùng, lệnh build/install, kết quả health,
    kết quả đăng nhập, từng mục checklist pass/fail, log lỗi liên quan, file đã
    sửa và test đã chạy. Nếu bị chặn bởi thao tác vật lý trên điện thoại, nói
    chính xác màn hình/nút tôi cần bấm rồi tiếp tục ngay sau đó.
```

Tài khoản trên chỉ dành cho đợt test. Sau khi bàn giao xong cần đổi mật khẩu
admin, vì prompt này chứa mật khẩu dạng rõ.
