# Quản lý PMV

App quản lý tài chính và công việc cá nhân trên Samsung Galaxy A54, dùng Supabase và dữ liệu local/offline.

- [Đặc tả sản phẩm — SRS](docs/README.md): tính năng, user story, luồng sử dụng, nghiệp vụ, dữ liệu, danh mục/tag và tiêu chí nghiệm thu.
- [AGENTS.md](AGENTS.md): đọc trước mọi tác vụ coding/documentation.
- `plans/`: chỉ dành cho plan mới, tên file và metadata phải có thời gian tạo thực tế theo quy tắc AGENTS.
- [Tài liệu kỹ thuật và lịch sử](reference/engineering/README.md): runbook, prompt, handoff và report; không phải yêu cầu hiện hành.
- `Quan_ly_PMV_Brand_Kit/`: nhận diện của app.

## Chọn đúng checkout

Mã PMV có `android/`, `linux/packages/finance_core/` và `linux/supabase/`. Repo còn lịch sử app v2 Quản lý Tao ở `apps/`, `packages/`, `backend/`. Nếu checkout hiện tại chỉ có cây app cũ, dùng `git worktree list` để tìm worktree PMV; không áp dụng nhầm thay đổi vào app đó.

Hướng dẫn kỹ thuật cũ được giữ để tra cứu, không tự coi cấu hình nhiều người dùng/collector/backend của app v2 là kiến trúc PMV. Không đưa `.env`, khóa ký hay dữ liệu tài chính cá nhân vào tài liệu hoặc Git.
