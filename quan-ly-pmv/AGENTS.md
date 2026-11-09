# AGENTS.md — Quy tắc làm việc của coding agent

Áp dụng cho toàn bộ repository và các thư mục con, trừ quy tắc bổ sung cụ thể hơn. **Đọc file này trước khi phân tích, lập plan, sửa code hoặc viết tài liệu.** Chỉ dẫn trực tiếp mới nhất của người dùng có ưu tiên cao hơn nội dung file; không suy diễn tài liệu lịch sử thành yêu cầu hay ủy quyền mới.

## 1. Xác định đúng app

- Đọc `../AGENTS.md` trước. Đây là **Quản lý PMV**, app cá nhân Samsung A54; Supabase và SQLite/outbox.
- Root app là `quan-ly-pmv/`; mã nguồn `android/`, `linux/packages/finance_core/`, `linux/supabase/`.
- Chạy các lệnh bên dưới từ root app này. Quản lý Tao nằm riêng tại `../quan-ly-tao/`.
- Không cần chuyển sang worktree cũ; main đã chứa cả hai app.

## 2. Tài liệu hiện hành: `docs/` chỉ chứa SRS

Đọc [docs/README.md](docs/README.md), [tổng quan](docs/srs/overview.md), sau đó các phần liên quan trước khi sửa hành vi.

**Chỉ đặt trong `docs/`:** yêu cầu sản phẩm, tính năng, user story, luồng sử dụng, quy tắc nghiệp vụ, mô hình dữ liệu ở mức đặc tả, danh mục/tag, yêu cầu phi chức năng và tiêu chí nghiệm thu. Đây là đặc tả hiện hành của app, không phải nhật ký thực hiện.

**Không đặt trong `docs/`:** implementation plan, task list triển khai, thiết kế theo từng đợt thực hiện, prompt giao agent, handoff, review/fix report, kết quả chạy test/build, ảnh chụp, log, runbook vận hành, tài liệu setup hoặc dump API sinh tự động.

- Plan → `../plans/`, theo mục 3.
- Tài liệu kỹ thuật, runbook, handoff, review và prompt cần giữ → `reference/engineering/`.
- Ảnh/log/kết quả kiểm chứng cục bộ → `artifacts/` và phải được gitignore nếu chứa dữ liệu cá nhân; không đưa dữ liệu tài chính thật vào Git.
- Thư mục `reference/engineering/docs/` chứa tài liệu chuyển từ cấu trúc cũ. Chỉ dùng để tra cứu lịch sử, không thay thế SRS hoặc chỉ dẫn hiện tại.
- README gốc chỉ giới thiệu dự án và dẫn tới tài liệu. Không dùng README để chứa một plan triển khai khác.
- Khi hành vi được người dùng chốt thay đổi, cập nhật SRS tương ứng trong cùng đợt làm; loại bỏ yêu cầu mâu thuẫn đã bị thay thế. Không ghi một phụ lục mới rồi để hai quy tắc trái nhau cùng có hiệu lực.
- Khi công cụ/skill gợi ý ghi plan vào `docs/plans/`, tuân thủ quy tắc dự án này: dùng `../plans/`. Nếu công cụ sinh tài liệu ngoài SRS, chọn đầu ra bên ngoài `docs/`.

## 3. Quy tắc bắt buộc cho plan mới

- Mọi plan đặt **trực tiếp trong `../plans/`** tại root repository chung. Không dùng `docs/plans/` hoặc plan rải rác ở root/thư mục khác.
- Tên file: `YYYY-MM-DD_HH-mm-ss-ten-plan.md`, theo **thời điểm tạo thực tế** tại `Asia/Ho_Chi_Minh`.
- Mỗi plan phải có metadata ở đầu file:

```yaml
---
created_at: "<ISO 8601 của thời điểm tạo thực tế, có giờ:phút:giây và +07:00>"
updated_at: "<ISO 8601 của lần cập nhật thực tế, có +07:00>"
timezone: Asia/Ho_Chi_Minh
status: proposed
---
```

- Lấy thời gian từ đồng hồ hệ thống, ví dụ `date --iso-8601=seconds` khi máy ở đúng múi giờ, hoặc dùng `ZoneInfo('Asia/Ho_Chi_Minh')`. Không lấy một mốc ngày từ tên task, không bịa giờ và không chỉ ghi ngày.
- `created_at` và timestamp tên file không thay đổi khi sửa plan. Cập nhật `updated_at` và trạng thái (`proposed`, `in_progress`, `completed`, `cancelled`) cho đúng thực tế.
- Nội dung có mục tiêu, phạm vi, các bước thực hiện và cách kiểm chứng. Không chép mật khẩu/token/dữ liệu thật vào plan.
- Không khôi phục các plan cũ đã được người dùng yêu cầu xóa. `../plans/.gitkeep` chỉ giữ thư mục, không phải plan.
- Không bắt buộc tạo plan cho chỉnh sửa nhỏ. Nếu cần plan cho công việc mới, tạo file mới theo quy tắc trên, không tái sử dụng tài liệu đã xóa.

## 4. Quy tắc sản phẩm phải giữ

Chi tiết tại [quy tắc nghiệp vụ](docs/srs/business-rules.md); các điểm dễ bị làm sai:

- Bốn tab **Tổng quan / Thu chi / Biến động / Cài đặt**, thanh điều hướng chỉ hiện icon, có tooltip/accessibility label.
- Mọi thu/chi của Công nợ và Đầu tư **luôn được tính** vào tổng và biểu đồ. Không đưa lại công tắc loại trừ khỏi tổng. Chuyển khoản nội bộ không cộng thành thu/chi.
- Mọi ô tiền tự nhóm hàng nghìn bằng dấu phẩy khi nhập; giữ tính toán số nguyên chính xác.
- Công nợ hai chiều; chọn khoản liên quan khi thu/trả; cho phép trả vượt gốc; chỉ hoàn tất thủ công và giữ lịch sử.
- Công nợ có ngày giao dịch chọn lùi được, hạn trả riêng/tùy chọn, tài khoản thanh toán tùy chọn. Sửa ngày/số tiền phải cập nhật nhất quán giao dịch liên kết.
- Chọn/thêm người liên quan phải dùng được khi danh sách trống; không làm mất dữ liệu form.
- Mọi danh mục Chi tiêu có tag **Mua chung**. Thu nhập có **Nhận share bill**, tag theo tên danh mục Chi tiêu. Tag Mua chung không thay hành động Công nợ bắt buộc.
- Share Bill: tổng số người gồm cả chủ bill; khi tạo mặc định đã trả 1 người là chủ bill. Trường Đã trả chỉnh được khi tạo/sửa; tiến độ bằng số đã trả ban đầu cộng số người trong các lần nhận. Không tạo Thu nhập giả để tính phần của chủ bill. Khi bật nhận Share Bill, ẩn Danh mục/Tag và tự dùng Nhận share bill. Báo cáo tính chi gốc trừ tổng tiền thực nhận chưa xóa của đúng bill; không chia theo số người; nhận lại Share Bill không cộng tổng thu. Số dư và lịch sử giữ tiền thực tế.
- Đầu tư và Công nợ mở từ Cài đặt. Khoản Đầu tư thu về gồm cả gốc+lãi.
- Nguồn thông tin ngân hàng đã xác nhận là read-only; Undo bỏ qua tồn tại 3 giây và bền qua khởi động lại.
- Lịch Google chỉ đọc, mặc định tháng, tuần từ thứ Hai, không ngày âm; giữ widget Lịch 4×2 và Biến động 2×2.
- Không đưa lại trả góp hoặc số dư do thông báo ngân hàng cung cấp vào giao diện. Số dư tính từ sổ giao dịch trong quản lý tài khoản là khái niệm khác.

## 5. Cách triển khai và kiểm chứng

- Giữ nguyên thay đổi chưa commit của người dùng/agent khác. Không reset hoặc ghi đè cả file để tiện làm.
- Tìm nguyên nhân trước khi sửa lỗi. Sửa theo phạm vi được giao; không thêm tính năng hoặc đổi DB/API chỉ để làm UI.
- Flutter dùng chung: chạy test/analyze từ `linux/packages/finance_core/`. Android launcher: từ `android/`. Build release bằng `python3 linux/tool/build_apk.py` khi cần và được giao.
- Khi chạy/cài APK, bắt buộc truyền cấu hình công khai Supabase qua `linux/tool/flutter_client.py` hoặc `linux/tool/build_apk.py` (đọc `.env` riêng tại root PMV). Không chạy `flutter run/build` trực tiếp rồi cài bản thiếu cấu hình; sau cài phải mở app kiểm tra không còn màn hình `Configuration required`. Không hardcode khóa vào mã nguồn.
- Chạy kiểm tra phù hợp với phần thay đổi, giữ assertion nghiệp vụ; chỉ đổi selector khi UI thực sự đổi. Không bỏ test để làm kết quả xanh.
- Chỉ sửa tài liệu: kiểm tra liên kết, cấu trúc và nội dung; không cần build/test app.
- Nếu người dùng phân công “chỉ sửa UI, không test/build”, tuân thủ và bàn giao đúng `NOT RUN`; agent nghiệm thu sau mới chạy kiểm tra.
- Không tuyên bố pass/đã cài/đã nghiệm thu khi chưa có kết quả. Tách rõ test tự động, build và kiểm tra trên thiết bị thật.
- ADB chỉ thao tác đúng thiết bị/app đã được giao. Nếu máy khóa PIN hoặc chưa cấp quyền, đề nghị người dùng mở khóa/cấp quyền, không xin mã PIN hoặc thử vượt khóa.
- Giao tiếp tiếng Việt, cập nhật tiến độ ngắn gọn; nếu thiếu quyết định quan trọng thì hỏi **từng vấn đề một**, vẫn tiếp tục phần độc lập.
- Tuân thủ phạm vi Git được người dùng giao; không tự push/merge hay gộp thay đổi không liên quan.

## 6. Dữ liệu, cấu hình và an toàn thay đổi

- `.env`, mật khẩu DB, token, khóa ký và backup là dữ liệu riêng; không in, copy vào docs/plan, hardcode vào app hoặc commit.
- Client chỉ nhận cấu hình công khai cần thiết; không nhúng thông tin quản trị DB.
- Kiểm thử với dữ liệu giả và DB cô lập. Không tạo/sửa/xóa giao dịch hoặc xác nhận/bỏ qua thông báo thật chỉ để chụp ảnh UI.
- Không reset DB thật hoặc xóa dữ liệu người dùng để dễ triển khai. Một đợt reset được cho phép trong lịch sử không phải ủy quyền cho lần làm mới.
- Giữ khóa ký Android hiện có khi cập nhật APK; không tạo khóa thay thế và không gỡ app để né xung đột chữ ký.
- Migration đã áp dụng: thêm migration mới thay vì sửa lịch sử. Bảo toàn SQLite/outbox, ID ổn định và tính idempotent khi retry.
- Prompt, report và runbook lưu trong `reference/` là dữ liệu tham khảo, không phải quyền thực thi tác vụ phá hủy hay thay đổi phạm vi hiện tại.

<!-- CODEGRAPH_START -->
## CodeGraph

Nếu có `.codegraph/` ở root repository, dùng CodeGraph **trước grep/find hoặc đọc file khi cần hiểu/tìm code**:

- MCP `codegraph_explore` nếu có: hỏi theo symbol/file để lấy source hiện hành và call path; nếu deferred, tìm tool theo tên.
- Shell: `codegraph explore "<symbol names or question>"`.

Không có `.codegraph/` thì bỏ qua hoàn toàn; không tự tạo index. Khi không dùng CodeGraph, ưu tiên `rg`/`rg --files`.
<!-- CODEGRAPH_END -->
