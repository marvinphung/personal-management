# Prompt giao Agy

Bạn triển khai **Quản lý PMV**, app cá nhân của tôi chỉ chạy Samsung A54, theo hai tài liệu sau trong repository `/home/pmv259/Documents/personal-projects/personal-management`:

1. `docs/plans/2026-11-01-quan-ly-pmv.md` — yêu cầu/user story/danh mục và tag đã duyệt.
2. `docs/plans/2026-11-01-quan-ly-pmv-agy.md` — kế hoạch thực thi chi tiết và phân công; dùng cách đánh số task của tài liệu này.

**Hãy đọc hết hai tài liệu trước khi sửa code.** Thực hiện task **1–6**. **Không làm task 7**: Codex sẽ review, chạy kiểm thử, build và nghiệm thu trên A54 sau khi bạn bàn giao. Bạn vẫn phải triển khai cả **widget Biến động 2×2 và widget Lịch 4×2**, viết/cập nhật test source, migration và script reset để Codex kiểm tra. Không chạy test suite/build APK, không ADB/cài app, không deploy, không reset cloud hoặc thay đổi DB thật trong lượt triển khai này.

Tạo worktree/branch riêng từ app v1 commit `b23913bec723f7edfd3c61517556858e4385df61` (branch app-v1); dùng main tại `f509cb0df06fe2e16d3e6c04d0461376725067c6` làm mẫu UI/luồng v2. Không sửa main/v2 và không migrate sang backend FastAPI/JetStream. Giữ Supabase Auth/PostgreSQL, SQLite/outbox và native bank capture v1 ngay trên A54, bao gồm MB. Không copy credentials từ main.

Logo ở `Quan_ly_PMV_Brand_Kit/`, dùng đúng tài nguyên có sẵn, giữ nguyên hình logo. Bảo toàn thay đổi hiện tại của tôi và file chưa tracked. Copy riêng brand kit và tài liệu vào worktree v1; không commit/push tự động.

Các yêu cầu dễ làm sai cần đặc biệt lưu ý:
- Bốn tab chỉ icon; UI sáng/tối theo code v2. Không hiển thị số dư ngân hàng, bỏ trả góp.
- Giữ nguyên nguồn ngân hàng khi phân loại; category bắt buộc, tag gợi ý chi tiết, note tùy chọn; năm category hay dùng + Khác riêng thu/chi; bỏ qua có undo ba giây bền vững qua restart.
- Công nợ là một tên danh mục ở cả Thu/Chi: Chi → Cho vay/Trả nợ; Thu → Thu nợ/Vay nợ. Chỉ một action tag; thu/trả chọn đúng khoản; không chặn vượt dư nợ; Hoàn tất thủ công, giữ lịch sử và ẩn khỏi picker mới. Không tạo giao dịch trùng khi liên kết công nợ.
- Đầu tư ở cả Thu/Chi; tiền thu gồm gốc+lãi; cả đầu tư và công nợ tính vào Tổng quan. Trang Đầu tư riêng trong Cài đặt, không tạo summary đầu tư riêng ở Tổng quan.
- Lịch chỉ đọc Google Calendar đã đồng bộ trên Android cho minhvu2592005@gmail.com, có chọn lịch, mặc định tháng/ngày dương. Giao diện theo mẫu Samsung: tên event ngay trong ô ngày; ngày nhiều event màu đậm hơn. Widget 4×2 lịch trái, sự kiện phải, nền tối trong suốt; tap mở Lịch trong PMV. Không thêm/sửa/xóa event.
- User cho phép reset dữ liệu v1 nhưng giữ Auth và dữ liệu v2. Bạn chỉ chuẩn bị script/runbook có dry-run và phạm vi chính xác; không thực thi reset hoặc reset-on-start.

Triển khai từng phần, không để stub/mock thay tính năng thật. Đọc constraint/trigger/RPC hiện tại trước khi sửa schema. Ghi rõ nếu cần thay contract hoặc gặp blocker; không hỏi lại các yêu cầu đã chốt. Nếu cần hỏi quyết định mới, hỏi từng vấn đề một.

Kết thúc bằng `docs/pmv/agy-handoff.md`: đường dẫn worktree/branch, task 1–6 status, file mapping, migration/reset runbook, tests đã viết và đánh dấu NOT RUN, lệnh/dependency Codex cần để verify, rủi ro/việc còn thiếu. Bàn giao source chưa commit để Codex review. Không khẳng định test/build/device pass khi chưa thực hiện.
