# Quản lý PMV Implementation Plan

> Khi triển khai: dùng skill executing-plans, thực hiện lần lượt các bước và kiểm tra kết quả từng phần.

**Goal:** Nâng cấp app v1 thành Quản lý PMV với giao diện và luồng hằng ngày của v2, dành riêng cho chủ app trên Samsung A54.

**Architecture:** Giữ Flutter, Supabase Auth, PostgreSQL/RPC, Drift/SQLite và outbox của v1. Một app Android trực tiếp nhận thông báo ngân hàng; không chuyển sang backend FastAPI/JetStream/collector riêng của v2. Lịch đọc dữ liệu Google đã đồng bộ qua Android Calendar Provider.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Drift, Supabase, Kotlin/Room/RemoteViews, Android Calendar Provider.

## Phân công bàn giao Agy / Codex

Kế hoạch thực thi chi tiết và phân công chính thức: [2026-11-01-quan-ly-pmv-agy.md](2026-11-01-quan-ly-pmv-agy.md). Prompt giao việc: [2026-11-01-quan-ly-pmv-agy-prompt.md](2026-11-01-quan-ly-pmv-agy-prompt.md).

Trong bản bàn giao, task **1–6 là triển khai của Agy**, task **7 là review, chạy kiểm thử, build và nghiệm thu của Codex** (theo danh sách bảy bước đã trình bày trong hội thoại). Hai widget vẫn thuộc phần triển khai của Agy. Các Task 1–8 phía dưới là phân rã kỹ thuật ban đầu, không phải cách đánh số phân công; dùng tài liệu bàn giao làm chuẩn để tránh nhầm Task 7 widget với task 7 nghiệm thu.

Agy viết/cập nhật test và chuẩn bị script migration/reset nhưng không thực thi reset cloud, không cài APK/đổi cấu hình thiết bị, không deploy và không nhận phần nghiệm thu. Không thực hiện các lệnh verify/build ghi dưới đây trong giai đoạn bàn giao Agy; chúng dành cho Codex chạy sau.

## 1. Mốc tham chiếu và giới hạn

- Base v1: `b23913bec723f7edfd3c61517556858e4385df61`, branch `app-v1` đã push.
- UI/luồng v2: main `f509cb0df06fe2e16d3e6c04d0461376725067c6`. Ưu tiên giao diện trong code hiện tại khi tài liệu khác code.
- Chỉ phát triển/nghiệm thu Samsung SM-A546E (A54), thiết bị đã thấy qua ADB: R5CW32L96TB.
- Không làm Linux/iOS, không bổ sung chức năng nhiều người dùng hay quản trị.
- Giữ tài khoản Supabase hiện tại. Người dùng cho phép reset toàn bộ dữ liệu app v1; không được xóa dữ liệu app v2 hoặc tài khoản Auth.
- Chưa reset, chưa thay đổi cloud trong giai đoạn lập kế hoạch.
- Brand kit: `Quan_ly_PMV_Brand_Kit/`; giữ nguyên logo, dùng tài nguyên Android có sẵn.

## 2. Giao diện và điều hướng đã chốt

- Tên hiển thị: **Quản lý PMV**.
- Bốn tab: Tổng quan / Thu chi / Biến động / Cài đặt. Thanh dưới chỉ hiện icon; giữ nhãn accessibility và tooltip.
- Màu sắc, typography, cards, sheets, sáng/tối theo v2 hiện tại.
- Các chức năng riêng trong Cài đặt: Công nợ, Đầu tư, Lịch, Ghi chú; quản lý danh mục/tag, ngân hàng và cấu hình app.
- Không hiển thị số dư ngân hàng. Không triển khai trả góp.
- Tổng quan vẫn tính giao dịch Đầu tư và Công nợ vào tổng thu/chi và biểu đồ. Không có khối theo dõi đầu tư riêng trên Tổng quan.
- Giữ nhập thu/chi thủ công, tìm kiếm, lọc, chỉnh phân loại và đồng bộ offline.

## 3. User stories và luồng

### US1 — Xem tài chính
Mở Tổng quan → chọn tháng → xem thu, chi, chênh lệch, biểu đồ → mở giao dịch liên quan. Chỉ tính giao dịch đã ghi sổ; chưa duyệt không tính. Đầu tư và Công nợ đều được tính theo chiều thu/chi.

### US2 — Phân loại biến động
Thông báo ngân hàng → native parser/inbox v1 → Biến động → Chấp nhận → danh mục → tag → ghi chú tùy chọn → xác nhận. Số tiền, chiều thu/chi, nguồn ngân hàng, thời gian và nội dung gốc chỉ đọc; ghi chú cá nhân riêng. Hiện năm danh mục dùng nhiều nhất và nút Khác, tính riêng thu/chi. Cho phép thêm danh mục/tag tại chỗ và giữ bản phân loại đang nhập.

Tag thông thường chọn nhiều; riêng Công nợ chọn đúng một tag nghiệp vụ. Bộ tag phải đủ chi tiết để ghi chú không bắt buộc. Với biến động, số tiền lấy từ thông báo; form nhập tay cho phép nhập tiền.

### US3 — Bỏ qua
Bỏ qua → ẩn ngay → Hoàn tác trong ba giây. Lưu slot/deadline cục bộ; khi hết hạn mới hoàn tất bỏ qua. Bỏ qua tiếp giao dịch khác sẽ hoàn tất mục trước và mở cửa sổ mới như v2. App bị đóng/mở lại xử lý đúng deadline, không hồi sinh mục đã hoàn tất.

Thông báo chuyển tiền giữa tài khoản bản thân vẫn vào Biến động; người dùng tự bỏ qua, không tự ghép hay tự loại. Chưa chốt việc xóa chức năng chuyển khoản thủ công cũ; không tự mở rộng thay đổi vào phần này.

### US4 — Nhập thủ công và dùng offline
Thu chi → thêm Thu/Chi → nhập tiền, danh mục, tag, ghi chú tùy chọn → ghi SQLite và outbox nguyên tử. UI cập nhật ngay. Retry lên Supabase không tạo trùng. Biểu thị rõ trạng thái offline/chờ đồng bộ/lỗi; lỗi không hiển thị thành danh sách rỗng.

### US5 — Công nợ
Công nợ là danh mục ở cả Thu và Chi, không dùng bốn danh mục riêng:

| Chiều | Tag nghiệp vụ | Liên kết |
|---|---|---|
| Chi | Cho vay | Chọn người, tạo khoản cho vay |
| Chi | Trả nợ | Chọn danh sách công nợ, chọn một khoản mình vay |
| Thu | Thu nợ | Chọn danh sách công nợ, chọn một khoản mình cho vay |
| Thu | Vay nợ | Chọn người, tạo khoản mình vay |

Tiền thu/trả cập nhật lịch sử và số dư đúng khoản. Không chặn vượt số còn nợ; cho phép hiển thị chênh lệch âm thay vì ép về 0. Không tự tất toán theo số dư. Có nút Hoàn tất do người dùng xác nhận; chuyển sang Đã hoàn tất, giữ lịch sử, loại khỏi danh sách chọn thu/trả mới. Chưa yêu cầu mở lại khoản đã hoàn tất.

Ghi sổ, liên kết khoản nợ, lịch sử thanh toán và outbox phải nguyên tử; retry không nhân đôi. Sửa/xóa giao dịch liên kết phải cập nhật đúng lịch sử và tổng, không thay đổi trạng thái Hoàn tất thủ công một cách ngầm định.

### US6 — Đầu tư
Cài đặt → Đầu tư → lọc thời gian/loại → Tổng tiền bỏ vào, Tổng tiền nhận về, Chênh lệch và lịch sử. Chi là vốn bỏ vào; Thu gồm cả gốc và lãi nhận về. Chênh lệch không gọi là lãi khi còn vốn chưa rút. Chọn nhiều tag; không cần tạo từng khoản đầu tư và ghép thu/chi.

### US7 — Trả sau
Chỉ ghi nhận hóa đơn đã thanh toán thực tế theo tag, không quản lý hạn thanh toán, dư nợ hoặc lịch trả góp.

### US8 — Lịch
Cài đặt → Lịch; mặc định tháng, thứ Hai đầu tuần, chỉ ngày dương. Bố cục tham chiếu ảnh Samsung Calendar người dùng gửi: lưới tháng, tiêu đề sự kiện ngay trong ngày, chọn ngày xem chi tiết. Không thêm/sửa/xóa sự kiện, không cần nút tạo mới từ ảnh tham chiếu.

Đọc tài khoản `minhvu2592005@gmail.com`, mặc định các lịch Google đang bật, có chọn/bỏ chọn từng lịch. ADB đã xác nhận Google Calendar được cài và Calendar Provider có các lịch tài khoản này bật sync/visible; chưa xác nhận mọi sự kiện đã cập nhật tới thời điểm mới nhất. Xin READ_CALENDAR trong luồng Lịch; không dùng ADB tự cấp quyền thay trải nghiệm người dùng. Không đọc tài khoản khác, không upload sự kiện lên Supabase.

Ngày có việc đổi màu, nhiều việc màu đậm hơn; dùng thang màu có giới hạn và số lượng/nhãn hỗ trợ, tránh chỉ dựa màu. Xử lý sự kiện lặp, cả ngày, nhiều ngày, timezone, thay đổi quyền và thay đổi danh sách lịch.

### US9 — Widget
- Biến động 2×2: số lượng chờ phân loại, không số tiền/tài khoản; chạm mở đúng tab.
- Lịch 4×2 theo ảnh người dùng: nền tối trong suốt, bo góc; lịch tháng bên trái, ngày và sự kiện bên phải; màu ngày theo số việc; chạm mở màn Lịch tương ứng. Không có ngày âm, không có thao tác thêm sự kiện.
- Màn Lịch và widget dùng chung bộ lịch đã chọn. Làm mới khi dữ liệu lịch thay đổi và ngày thay đổi, khi app quay lại; không hứa OS chạy nền đúng giây.
- Kiểm tra cold/warm start, không lặp redirect khi resume bình thường, widget khi thiếu quyền/không sự kiện.

### US10 — Ghi chú
Giữ màn ghi chú cá nhân riêng, lưu/ghim, truy cập từ Cài đặt. Không bổ sung nhắc lịch hoặc tự biến ghi chú thành Google event.

## 4. Danh mục và tag đã duyệt

Tag dưới đây là nhãn hiển thị. Kiểm tra cách chuẩn hóa tag của v1 trước khi quyết định trường lưu để nhãn tiếng Việt không bị mất.

### Chi
- **Ăn uống:** Ăn sáng, Ăn trưa, Ăn tối, Ăn khuya, Ăn vặt, Cà phê, Nước uống, Đồ uống khác, Đi chợ, Siêu thị thực phẩm, Đặt đồ ăn, Nhà hàng, Nhậu, Tiệc/tụ tập.
- **Đi lại:** Đổ xăng, Xe ôm, Taxi, Gửi xe, Sửa xe.
- **Mua sắm:** Quần áo, Giày dép, Phụ kiện, Đồ cá nhân, Đồ gia dụng, Đồ điện tử, Đồ dùng công việc.
- **Nhà & hóa đơn:** Tiền nhà, Tiền Điện + nước, Internet, Điện thoại/4G/5G, Phí dịch vụ.
- **Giải trí:** Xem phim, Game, Nghe nhạc, Đăng ký dịch vụ, Đi chơi, Sự kiện/biểu diễn.
- **Sức khỏe:** Khám bệnh, Thuốc, Thể thao, Bảo hiểm, Thực phẩm.
- **Gia đình & quà tặng:** Biếu bố mẹ, Hỗ trợ người thân, Quà tặng, Sinh nhật, Đám cưới, Đám tang, Lễ/Tết.
- **Du lịch:** Di chuyển, Lưu trú, Ăn uống, Tham quan, Mua quà, Tour.
- **Chi khác:** Phí ngân hàng, Phí giấy tờ, Từ thiện, Chi chưa phân loại.
- **Trả sau:** Shopee, TikTok, Thẻ tín dụng, Khác.
- **Công nợ:** Cho vay, Trả nợ.
- **Đầu tư:** Chứng khoán, Quỹ đầu tư, Crypto, Vàng, Tiết kiệm, Góp vốn, Khác.

### Thu
- **Lương:** Lương chính, Phụ cấp, Làm thêm giờ.
- **Thưởng:** Thưởng tháng, Thưởng quý, Thưởng Tết, Thưởng dự án, Thưởng khác.
- **Làm thêm:** Việc ngoài, Freelance, Gia sư.
- **Được tặng:** Gia đình, Bạn bè, Người yêu, Mừng tuổi, Quà bằng tiền.
- **Thu khác:** Hoàn tiền, Lãi tiết kiệm, Bán đồ cá nhân, Khác.
- **Công nợ:** Thu nợ, Vay nợ.
- **Đầu tư:** dùng cùng nhãn tag như chiều Chi.

Không seed Học tập, Kinh doanh. Hai chiều Đầu tư/Công nợ có thể là bản ghi danh mục khác nhau do schema phân hướng; dùng behavior rõ ràng, không dựa tên/tag đã dịch để xử lý nghiệp vụ.

## 5. Thứ tự triển khai

### Task 1 — Chuẩn bị nhánh, khảo sát và chốt contract dữ liệu
- Tạo nhánh triển khai từ app-v1, giữ main/v2 nguyên vẹn và bảo toàn brand kit chưa tracked. Không ghi đè worktree hiện tại.
- Đọc hướng dẫn repo và kiểm tra .codegraph tại worktree trước khi tìm mã.
- Xem baseline: `android/`, `linux/packages/finance_core/`, `linux/supabase/migrations/`, `linux/tool/`.
- Đối chiếu UI v2 tại `packages/finance_core/lib/app/` và `features/`; chỉ port UI/hành vi cần thiết, không chép API/sync v2.
- Đọc schema/category/tags/debts/payments/finance_apply và kiểm tra dữ liệu thực bằng metadata cần thiết. Xác định namespace v1/v2, chủ sở hữu, chữ ký APK và package v1 trước reset/cài đè.
- Viết contract cụ thể cho nhãn tag, behavior danh mục, Công nợ thu/chi, completed_at và receipt, tương thích outbox. Chỉ chốt migration sau khi đọc nguồn; không đoán tên constraint.

### Task 2 — Nền UI và nhận diện
- Sửa v1 `lib/app/theme.dart`, `router.dart`, `widgets.dart`, `settings.dart`, translations; Android manifest/resources, tài nguyên và pubspec.
- Dùng brand kit 01-brand/03-android; kiểm tra icon legacy/adaptive/monochrome và splash theo API Android thực tế, không dùng ảnh splash kéo giãn.
- Áp dụng bốn tab icon-only và shared components cho tiền, danh sách, lọc, trạng thái async.
- Verify analyze và widget tests cho navigation, text scale, light/dark; chụp màn trên A54.

### Task 3 — Schema, seed, Công nợ và reset có phạm vi
- Thêm migration kế tiếp trong `linux/supabase/migrations/` và SQL tests; cập nhật `core/database/{record,local_database,finance_repository}.dart`, `core/utils/ledger.dart`, `features/debts/` theo contract Task 1.
- Bổ sung seed danh mục/tag, loại trừ seed cũ tự tái tạo. Test bootstrap và sync.defaults trước khi cloud rollout.
- Bỏ giới hạn repayment theo dư nợ ở cả Dart/SQLite/RPC/SQL; giữ kiểm tra số tiền hợp lệ và quyền sở hữu. Thêm trạng thái hoàn tất thủ công đồng bộ.
- Cho Công nợ vào tổng thu/chi đúng một lần; không tạo thêm dòng sổ cái từ một thông báo đã được ghi nhận.
- Test đủ bốn nghiệp vụ, trả nhiều lần/vượt dư nợ, hoàn tất thủ công, rollback, retry, sửa/xóa liên kết, RLS.
- Chuẩn bị reset script có dry-run/count phạm vi user v1, không DROP schema public hoặc xóa Auth/v2. Ngừng writers cũ khi cutover, reset cloud và cache/outbox/native inbox của v1 có phối hợp để dữ liệu cũ không upload trở lại; giữ fingerprint tombstone tối thiểu nếu cần để không nhập lại thông báo cũ.
- Chạy migration/reset chỉ sau khi xác định chính xác phạm vi và đã có bản build tương thích để cutover.

### Task 4 — Biến động và nhập thu/chi
- Sửa `features/bank_import/`, `features/transactions/`, catalog và repository, native bridge nếu contract cần.
- Tách form phân loại read-only nguồn ngân hàng khỏi form nhập tay. Thêm gợi ý danh mục và tag, tạo inline giữ draft, Công nợ chọn người/khoản.
- Implement undo ba giây với persistence và đồng bộ count widget/inbox; không xóa native payload trước khi quyết định bền vững.
- Không vô tình tắt parser MB hoặc đưa điều kiện tài khoản unmasked của v2 vào v1.
- Test retry sau local commit/native finish lỗi, undo qua restart/deadline, hai discard liên tiếp, tạo tag khi phân loại và số lượng badge.

### Task 5 — Tổng quan, Thu chi và chức năng phụ
- Port bố cục v2 vào v1 `features/dashboard/`, `transactions/`, `notes/`, `app/settings.dart`.
- Thêm trang Đầu tư và route với tổng/lọc/lịch sử từ ledger hiện có; không thêm mô hình lãi giả định.
- Hoàn thiện trang Công nợ, lịch sử khoản và nhóm Đã hoàn tất.
- Loại UI/lối vào trả góp; xem mọi caller trước xóa mã hoặc cột. Không làm migration phá dữ liệu v2.
- Verify totals chứa đầu tư/công nợ, không chứa pending; không hiển thị bank balance, lọc/tìm và sửa ghi chú.

### Task 6 — Lịch trong app
- Thêm Dart models/repository/providers/screens trong shared package v1; Kotlin Calendar Provider adapter trong Android runner, READ_CALENDAR và channel.
- Query theo calendar IDs đã chọn, cửa sổ ngày; dùng Instances cho recurrence thay vì chỉ đọc Events thô. Chỉ đọc trường cần hiển thị.
- Dùng state selection chung cho widget, refresh permission/data/lifecycle; thiết kế month grid theo ảnh, count shading, chi tiết ngày/sự kiện.
- Test fake provider cho recurrence/all-day/multi-day/timezone/quyền từ chối hoặc thu hồi, tháng 4–6 tuần, chọn lịch. Verify chỉ tài khoản được chọn.

### Task 7 — Hai widget Android
- Cập nhật v1 native bank widget/RemoteViews 2×2; thêm Calendar widget provider/layout/info 4×2.
- Cùng nguồn inbox/lịch với app, intent mở đúng đích, consume-once, theme rõ trên nền wallpaper.
- Test render/count/permission/date boundary/deep link bằng native tests và đặt widget thật trên Home Screen A54, resize, cold/warm launch.

### Task 8 — Nghiệm thu và bàn giao
- Chạy analyze/tests shared package và Android launcher; Kotlin Gradle tests; SQL/RLS trên môi trường test cô lập. Không chạy mutation test vào dữ liệu v2.
- Lệnh baseline: `(cd linux/packages/finance_core && flutter analyze && flutter test)`, `(cd android && flutter analyze && flutter test)`, `(cd android/android && ./gradlew :app:testDebugUnitTest)`; điều chỉnh theo cấu trúc cuối và SDK thực tế.
- Build qua `linux/tool/flutter_client.py` chỉ truyền public client config; giữ app ID/chữ ký tương thích nếu cài đè. Không đổi signing identity tùy tiện.
- Trên A54: đăng nhập, từng tab, các nghiệp vụ Công nợ, đầu tư, tag, undo, offline thật/retry, cold relaunch, calendar read, hai widget và sáng/tối/cỡ chữ.
- Thông báo thật chỉ xác minh khi có sự kiện thực được người dùng cho phép; không giả giao dịch tài chính thật để tạo bằng chứng.
- Bàn giao APK đúng version/hash, ảnh trước/sau, test đã chạy và giới hạn còn lại; không khẳng định live capture hay widget background chỉ từ unit tests.

## 6. Tiêu chí hoàn thành

1. Quản lý PMV chạy A54 với logo đã chọn, UI v2, bốn icon tabs.
2. Seed đúng toàn bộ bộ danh mục/tag đã duyệt; không bắt buộc ghi chú.
3. Phân loại, offline/retry và undo không tạo trùng/mất dữ liệu; count widget nhất quán.
4. Công nợ đủ bốn tag, chọn khoản thu/trả, không chặn vượt dư nợ, hoàn tất thủ công.
5. Đầu tư/Công nợ tính vào Tổng quan; không bank balance/trả góp.
6. Lịch chỉ đọc Google account đã chọn, tháng/ngày dương, widget 4×2 theo mẫu và shading theo số việc.
7. Reset chỉ dữ liệu v1 đã được cho phép, giữ Auth và v2; không tái upload dữ liệu cũ sau cutover.

## 7. Điểm kỹ thuật cần giải quyết khi khảo sát

- Permission hệ điều hành, credentials, khả năng đồng bộ Google và signing phải kiểm tra trên máy; không giả định quyền đã có.
- Chuẩn hóa tên tag v1, constraint trả nợ và logic loại công nợ khỏi thống kê cần thay có test; port UI đơn thuần không đáp ứng yêu cầu.
- Ngưỡng màu theo số sự kiện, xử lý text overflow và mức trong suốt sẽ tinh chỉnh bằng ảnh A54, không cần hỏi thêm từng thông số mỹ thuật.
- Nếu có quyết định sản phẩm mới ảnh hưởng luồng, chỉ hỏi một vấn đề mỗi lần như người dùng yêu cầu.
