# Kết nối User App Android với local server trên Mac mini

Tài liệu này dành cho một máy/agent Codex khác đang build và test Android User
App. Backend cần dùng là local development stack hiện tại trên Mac mini M1,
không phải backend production cũ.

## Endpoint cần dùng

```text
API_BASE_URL=https://api.xn--qun-l-tao-49a0064f.id.vn/v1
Health check=https://api.xn--qun-l-tao-49a0064f.id.vn/v1/health/ready
Swagger=https://api.xn--qun-l-tao-49a0064f.id.vn/docs
```

Cloudflare Tunnel chuyển tiếp HTTPS công khai tới backend local
`127.0.0.1:8001`. Thiết bị test không cần tham gia Tailscale.

Không dùng các endpoint sau cho đợt test này:

- `https://fendee.tail95473a.ts.net/v1`: endpoint Tailscale cũ.
- `http://100.123.5.30:8001`: backend local chỉ bind loopback và kết nối này không có TLS.
- `10.0.2.2`: chỉ phù hợp khi Android Emulator chạy ngay trên chính Mac mini.

## Tài khoản demo

```text
Username: demo
Password: Demo@123456
Status: active
```

Database demo hiện có danh mục/tag mặc định, 7 giao dịch, một bank binding,
một ví tiền mặt, một khoản công nợ, một ghi chú và 3 giao dịch ngân hàng đang
chờ phân loại trong JetStream.

## Yêu cầu trên thiết bị Android

1. Mở URL health check bằng Chrome trên Android.
2. Chỉ tiếp tục nếu nhận JSON có `status: ready`, `database: connected` và
   `broker: connected`.
3. Bật USB debugging nếu cài app qua ADB.

## Build và chạy từ repository

Tại thư mục gốc repository:

```bash
flutter devices
API_BASE_URL=https://api.xn--qun-l-tao-49a0064f.id.vn/v1 \
  python3 tool/flutter_client.py user run -d DEVICE_ID
```

`tool/flutter_client.py` chỉ truyền biến public `API_BASE_URL` vào Flutter;
nó không truyền database password hay backend secrets.

Nếu cần build APK thay vì `flutter run`:

```bash
cd apps/user_app
flutter build apk --debug \
  --dart-define=API_BASE_URL=https://api.xn--qun-l-tao-49a0064f.id.vn/v1
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Không sửa URL mặc định trong source code và không commit credentials. API URL
phải được truyền bằng `--dart-define` hoặc qua `tool/flutter_client.py`.

## Checklist kiểm thử

1. Đăng nhập bằng tài khoản `demo`.
2. Xác nhận dashboard có dữ liệu thu/chi và biểu đồ.
3. Mở danh sách giao dịch và kiểm tra dữ liệu mẫu.
4. Mở màn hình **Biến động** và xác nhận có 3 giao dịch chờ phân loại.
5. Phân loại một giao dịch, kiểm tra giao dịch biến mất khỏi inbox và xuất hiện
   trong sổ giao dịch.
6. Kiểm tra thao tác hoàn tác trong 3 giây.
7. Tắt mạng, tạo một thay đổi local, bật mạng lại và kiểm tra đồng bộ.
8. Khởi động lại app và xác nhận phiên đăng nhập/dữ liệu vẫn còn.

Nếu đăng nhập được nhưng snapshot lỗi, lưu lại HTTP status, response body,
Android logcat và thời điểm xảy ra lỗi. Không reset hay xóa database phía server.

## Prompt gửi cho Codex ở máy test Android

```text
Bạn đang test Android User App của repository personal-management.

Hãy dùng tài liệu docs/runbooks/android-remote-local-server.md làm nguồn hướng
dẫn chính. Backend local hiện đã chạy trên Mac mini và được publish riêng qua:

API_BASE_URL=https://api.xn--qun-l-tao-49a0064f.id.vn/v1

Endpoint được public qua Cloudflare Tunnel, không cần Tailscale. Trước tiên hãy
mở hoặc curl endpoint /v1/health/ready và chỉ tiếp tục khi database + broker đều
connected. Sau đó build/run apps/user_app với API_BASE_URL truyền qua
--dart-define (ưu tiên tool/flutter_client.py), cài lên thiết bị Android, đăng
nhập bằng tài khoản demo ghi trong runbook và thực hiện toàn bộ checklist.

Nếu gặp lỗi, tự chẩn đoán và sửa các lỗi thuộc source/build/config Android,
nhưng không thay đổi hoặc xóa database server, không dùng backend port 443 cũ,
không hardcode credentials/API URL vào source và không làm mất thay đổi hiện có.
Ghi lại lệnh đã chạy, kết quả từng checklist, log lỗi liên quan và các file đã
sửa. Chạy test phù hợp sau khi sửa.
```
