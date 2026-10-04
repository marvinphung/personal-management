# Quản lý Tao — Hệ thống Quản lý Tài chính Cá nhân Đa người dùng

Tài liệu mô tả dự án được duy trì tại **[docs/project.md](docs/project.md)**: luồng sử dụng, luồng dữ liệu JetStream/Supabase, cấu hình và vận hành Mac mini. Các plan triển khai đã được thay thế bằng tài liệu này. Phiên sửa lỗi hiện tại chỉ xác minh backend; kiểm tra app/thiết bị để sau.

Hệ thống quản lý tài chính cá nhân gồm ba thành phần chính:
1. **Backend Service** (`backend/`): Dịch vụ FastAPI Python kết nối PostgreSQL (schema chuyên dụng `qlt`), đảm bảo xác thực người dùng/quản trị viên, đồng bộ snapshot, phân loại giao dịch biến động ngân hàng và chống trùng lặp.
2. **Collector App** (`apps/collector_app/`): Ứng dụng Android chạy 24/7 trên điện thoại thu thập thông báo biến động số dư ngân hàng (BIDV, VietinBank, Vietcombank, Techcombank), tích hợp giao diện quản trị người dùng và thiết bị.
3. **User App** (`apps/user_app/`): Ứng dụng di động (Android & iOS) dành cho người dùng cuối: ghi chép thu chi, phân loại biến động ngân hàng (với tính năng hoàn tác 3 giây), theo dõi công nợ, hoạt động ngoại tuyến và hiển thị widget đếm số lượng giao dịch chờ duyệt trên màn hình chính.

> **Lưu ý kiến trúc:** Ứng dụng desktop Linux cũ đã được chính thức thay thế bởi hệ thống client di động và backend FastAPI tập trung. Mã nguồn liên quan đến desktop runner Linux đã được dọn dẹp.

---

## Mục lục

- [1. Yêu cầu hệ thống & Môi trường](#1-yêu-cầu-hệ-thống--môi-trường)
- [2. Cấu hình biến môi trường (.env)](#2-cấu-hình-biến-môi-trường-env)
- [3. Khởi tạo Backend & Cơ sở dữ liệu](#3-khởi-tạo-backend--cơ-sở-dữ-liệu)
- [4. Chạy và Build ứng dụng Android](#4-chạy-và-build-ứng-dụng-android)
- [5. Hướng dẫn chạy iOS Simulator](#5-hướng-dẫn-chạy-ios-simulator)
- [6. Cấu trúc thư mục dự án](#6-cấu-trúc-thư-mục-dự-án)
- [7. Kiểm thử & Đảm bảo chất lượng (T23)](#7-kiểm-thử--đảm-bảo-chất-lượng-t23)
- [8. Tài liệu vận hành (Runbooks)](#8-tài-liệu-vận-hành-runbooks)

---

## 1. Yêu cầu hệ thống & Môi trường

- **Hệ điều hành:** Linux (Ubuntu 24.04 LTS x86_64) hoặc macOS.
- **Python:** 3.12+ cùng công cụ quản lý gói `uv`.
- **Flutter SDK:** 3.24+ (Dart 3.5+).
- **PostgreSQL:** Phiên bản 15 hoặc 16 (hỗ trợ schema riêng `qlt`).
- **Android Development:** JDK 17/21, Android SDK Platform 34/35, Command-line Tools.
- **Thiết bị thật:** Điện thoại Android kết nối cáp USB (đã bật USB Debugging) để phục vụ kiểm thử thiết bị và cài đặt collector.

---

## 2. Cấu hình biến môi trường (`.env`)

Tạo file `.env` từ file mẫu `.env.example`:

```bash
test -f .env || cp .env.example .env
chmod 600 .env
```

Các biến cấu hình chính:

```dotenv
# Cấu hình an toàn cho Flutter client (truyền qua --dart-define)
API_BASE_URL=http://localhost:8000/v1

# Cấu hình Backend server (BẢO MẬT: Không commit vào Git)
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres?sslmode=disable
DATABASE_SCHEMA=qlt
DEDUP_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef

ENVIRONMENT=development
HOST=0.0.0.0
PORT=8000
```

---

## 3. Khởi tạo Backend & Cơ sở dữ liệu

### 3.1. Chạy Migration Database

```bash
uv --project backend run python src/qlt/migrate.py
```

Lệnh trên sẽ tạo và cập nhật schema `qlt`, bao gồm bảng phân quyền người dùng, liên kết tài khoản ngân hàng, biến động chờ duyệt, sổ cái giao dịch và công nợ. **Không ảnh hưởng đến schema `public`.**

### 3.2. Khởi tạo tài khoản Quản trị viên (Bootstrap Admin)

```bash
uv --project backend run python src/qlt/bootstrap_admin.py admin
```

### 3.3. Khởi động Backend

```bash
uv --project backend run uvicorn qlt.main:app --host 0.0.0.0 --port 8000 --reload
```

Kiểm tra trạng thái sẵn sàng:
```bash
curl http://localhost:8000/v1/health/ready
```

Hoặc triển khai qua Docker Compose:
```bash
docker compose -f deploy/compose.yaml up -d --build
```

---

## 4. Chạy và Build ứng dụng Android

### 4.1. Khởi chạy ứng dụng phát triển qua USB

Kết nối điện thoại Android qua USB, kiểm tra bằng `flutter devices`, sau đó chạy:

```bash
# Chạy User App:
python3 tool/flutter_client.py user run -d <DEVICE_ID>

# Chạy Collector App:
python3 tool/flutter_client.py collector run -d <DEVICE_ID>
```

### 4.2. Build APK Release có ký số

Script `tool/build_apk.py` tự động quản lý keystore cục bộ tại `apps/user_app/signing/`:

```bash
# Build User App APK:
python3 tool/build_apk.py user

# Build Collector App APK:
python3 tool/build_apk.py collector
```

File APK release xuất tại:
- `apps/user_app/build/installers/user-release-1.0.0.apk`
- `apps/collector_app/build/installers/collector-release-1.0.0.apk`

---

## 5. Hướng dẫn chạy iOS Simulator

Chi tiết các bước thiết lập, biên dịch và kiểm thử widget trên macOS được ghi lại tại:
👉 [docs/runbooks/ios-simulator.md](docs/runbooks/ios-simulator.md)

Các lệnh chính:
```bash
cd apps/user_app
flutter build ios --simulator --dart-define=API_BASE_URL="http://localhost:8000"
xcrun simctl openurl booted "quanlytao://bank-inbox"
```

---

## 6. Cấu trúc thư mục dự án

```text
.
├── apps/
│   ├── collector_app/          # Android collector app (24/7 capture + admin UI)
│   └── user_app/               # Flutter mobile user app (Android & iOS)
│       ├── android/            # Native Kotlin Android runner + AppWidget
│       ├── ios/                # Native Swift iOS runner + WidgetKit Extension
│       └── signing/            # Khóa ký APK release cục bộ (chỉ lưu trên máy dev)
├── backend/                    # Dịch vụ FastAPI Python & Migration
│   ├── migrations/             # Schema 001..005 cho schema qlt
│   ├── src/qlt/                # Mã nguồn auth, admin, ingest, ledger, sync, widgets
│   └── tests/                  # Bộ kiểm thử tích hợp (integration tests)
├── deploy/                     # Dockerfile, Docker Compose, Caddyfile, macOS launchd
├── docs/                       # Tài liệu thiết kế, kế hoạch và runbooks
│   ├── project.md              # Mô tả đầy đủ dự án, luồng và cấu hình hiện tại
│   └── runbooks/               # Hướng dẫn vận hành server, collector, backup, acceptance
├── packages/
│   ├── api_client/             # Dart HTTP client dùng chung giữa hai app mobile
│   └── finance_core/           # Domain logic, SQLite database, outbox, giao diện Flutter
└── tool/                       # Scripts build APK, launch client, kiểm tra rò rỉ secret
```

---

## 7. Kiểm thử & Đảm bảo chất lượng (T23)

Chạy `uv run pytest tests -q` trong `backend/` với PostgreSQL/NATS test cô lập. Lệnh khởi tạo và giới hạn của kết quả kiểm thử được ghi ở [docs/project.md](docs/project.md#9-verification-and-remaining-scope). Kiểm tra Flutter, Android USB và iOS Simulator là bước riêng, hiện để sau theo yêu cầu của người dùng.

Kiểm tra rò rỉ secret trong mã nguồn mobile:
```bash
python3 tool/check_mobile_secrets.py
```

---

## 8. Tài liệu vận hành (Runbooks)

- [Server Operations & Deployment](docs/runbooks/server.md)
- [Collector Phone Setup & Handover](docs/runbooks/collector.md)
- [Backup, Restore & Secrets Rotation](docs/runbooks/backup.md)
- [Bank Notification Fixtures & Parsers](docs/runbooks/bank-fixtures.md)
- [iOS Simulator & Widget Verification](docs/runbooks/ios-simulator.md)
- [Acceptance & Validation Rehearsal](docs/runbooks/acceptance.md)
