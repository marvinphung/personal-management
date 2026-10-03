# Quản lý Tao — User App

This Flutter mobile application targets Android and iOS and depends on `packages/finance_core` and `packages/api_client`.

- **Development Run:** `python3 tool/flutter_client.py user run`
- **Build APK:** `python3 tool/build_apk.py user`
- **Configuration:** Injected via `--dart-define=API_BASE_URL=...` (no database credentials or private secrets are compiled into the app).
