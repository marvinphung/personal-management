# Quản lý PMV

App cá nhân Android trên Samsung Galaxy A54; cloud Supabase, local SQLite/outbox.

- Android launcher: `android/`.
- Flutter dùng chung: `linux/packages/finance_core/`.
- Migration và kiểm thử DB: `linux/supabase/`.
- [SRS](docs/README.md), [quy tắc agent](AGENTS.md), [tài liệu kỹ thuật](reference/engineering/).
- Chạy lệnh từ `quan-ly-pmv/`: `python3 linux/tool/flutter_client.py android run`; build: `python3 linux/tool/build_apk.py`.
- Cấu hình riêng tại `.env`, khóa ký riêng tại `android/signing/`; phục hồi từ bản riêng tư khi cần build.
- Plan chung ở `../plans/`. Worktree PMV cũ chỉ là checkout lịch sử, không phải nơi mặc định để sửa app nữa.
