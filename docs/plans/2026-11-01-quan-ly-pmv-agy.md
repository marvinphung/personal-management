# Quản lý PMV — Kế hoạch triển khai chi tiết cho Agy

**Goal:** Triển khai app Android cá nhân trên nền v1 theo đặc tả đã duyệt, giao source để Codex review và thực hiện task 7.

**Architecture:** Flutter/Supabase Auth/Drift/outbox v1; Kotlin nhận thông báo trên A54 và đọc Calendar Provider. Port UI và hành vi cần thiết từ v2; không port backend/API client, JetStream hay collector v2.

**Tech Stack:** Flutter, Dart, Riverpod, go_router, SQLite, Supabase RPC/PostgreSQL, Kotlin/Room/RemoteViews.

## A. Tài liệu và phạm vi

Đọc toàn bộ [đặc tả đã duyệt](2026-11-01-quan-ly-pmv.md), đặc biệt danh mục/tag, các user story và ràng buộc dữ liệu. Tài liệu này hướng dẫn thực thi, không thay đổi yêu cầu đã duyệt.

Đánh số bàn giao duy nhất:

| Task | Người làm | Kết quả |
|---|---|---|
| 1 | Agy | Worktree v1 và contract dữ liệu |
| 2 | Agy | Nhận diện và nền UI bốn tab |
| 3 | Agy | Schema/seed, Công nợ, script reset chưa chạy |
| 4 | Agy | Biến động, undo, thu/chi offline |
| 5 | Agy | Tổng quan và chức năng phụ |
| 6 | Agy | Lịch, hai widget, source/test và tài liệu bàn giao |
| 7 | Codex | Review, thực thi kiểm thử/build, cutover được phép và nghiệm thu A54 |

Agy viết test có ý nghĩa nhưng không phụ trách chạy bộ kiểm thử/build/nghiệm thu. Có thể đọc file, kiểm tra diff và chạy lệnh Git không phá hủy; không báo test pass nếu chưa chạy. Nếu môi trường bắt buộc bước sinh mã/dependency resolution để hoàn thiện source, ghi rõ bước cần thiết và mọi output; không biến thành kiểm thử/build APK/nghiệm thu thiết bị.

Không commit/push tự động; để source và tài liệu review được trong worktree. Không sửa main/v2, không deploy, không reset dữ liệu, không thao tác điện thoại. Người dùng đã cho phép reset v1 nhưng giao Agy triển khai source, Codex kiểm tra phạm vi rồi xử lý cutover.

## B. Task 1 — Worktree, khảo sát, contract

### B1. Tạo môi trường đúng phiên bản
1. Tại repo gốc, ghi `git status --short`, `git branch -a`, `git worktree list` vào report; không restore/clean thay đổi người dùng. Có thay đổi xóa `logo.png` và brand kit chưa tracked ở lúc lập plan, không tự phục hồi/xóa/commit chúng.
2. Xác nhận v1 `b23913bec723f7edfd3c61517556858e4385df61` và v2 `f509cb0df06fe2e16d3e6c04d0461376725067c6` tồn tại. Không pull main rồi vô tình đổi mẫu tham chiếu.
3. Tạo worktree anh em `../personal-management-pmv`, branch `feature/quan-ly-pmv` từ commit v1. Nếu tên đã tồn tại, kiểm tra có đúng phiên làm việc không; không force overwrite.
4. Copy riêng ba tài liệu plan/prompt và brand kit sang worktree mới, giữ nguyên nguồn. Không copy `.env` hay credentials một cách mù quáng. Không đưa đường dẫn tuyệt đối máy hiện tại vào runtime app.
5. Đọc AGENTS.md áp dụng; nếu có `.codegraph/` dùng CodeGraph trước khi tìm nguồn. Base v1 không có chỉ mục khi khảo sát ban đầu.

### B2. Đọc đúng các lớp v1 và mẫu v2
- V1: `linux/packages/finance_core/lib/app/{app,providers,router,theme,widgets,settings}.dart`.
- V1: `core/database/{record,local_database,finance_repository}.dart`, `core/sync/sync_engine.dart`, `core/utils/{ledger,money,tag_name}.dart` (các đường tương đối từ lib).
- V1: `features/{bank_import,transactions,debts,catalog,dashboard,notes}/` và native `android/android/app/src/main/kotlin/app/personalfinance/finance_android/banknotification/`.
- V1: migrations `001`–`006`, SQL tests và `linux/tool/database.py`.
- V2: đọc qua checkout main hoặc `git show`, `packages/finance_core/lib/app/`, `features/`, `docs/project.md`, `docs/user-app-design-spec.md`; không copy nguyên repository v2 sang v1.

### B3. Ghi contract trước khi sửa schema
Tạo `docs/pmv/data-contract.md`:
1. Bảng mapping source v1 → màn v2 → hành vi PMV; đánh dấu giữ/thay/bỏ và file chịu trách nhiệm.
2. Quyết định trường nhãn tag tiếng Việt và khóa nghiệp vụ ổn định. V1 chuẩn hóa tag không dấu: không âm thầm làm mất nhãn đã duyệt hoặc nhận diện nghiệp vụ bằng tên hiển thị.
3. Tách hai bản ghi danh mục theo chiều thu/chi nếu schema cần; UI cùng tên Đầu tư/Công nợ. Định nghĩa behavior danh mục và bốn action tag Công nợ có khóa ổn định.
4. Định nghĩa liên kết transaction↔debt/payment, status/hoàn tất và idempotency. Dùng một thao tác nguyên tử, không save transaction rồi gọi createDebt tạo transaction thứ hai.
5. Giữ đơn vị tiền nguyên, currency, owner constraints; ngân hàng read-only không đồng nghĩa bỏ validation.
6. Ghi mapping nhãn/route, cách đếm widget và nguồn lịch, quyền, timezone.

**Đầu ra:** worktree đúng base và contract không còn phụ thuộc vào backend v2. Chưa cần cloud credentials để làm phần này.

## C. Task 2 — Nhận diện, theme, shell

**Sửa:** v1 `android/android/app/src/main/AndroidManifest.xml`, Android resources, `android/pubspec.yaml` nếu cần assets; shared `lib/app/{theme,router,widgets,settings}.dart`, `lib/core/localization/translations.dart`.

1. Đổi app label/title thành Quản lý PMV; giữ package ID v1, không dùng ID app.quanlytao.user.
2. Copy asset cần dùng vào app resources/assets. Dùng icon mật độ từ `03-android/mipmap-*`, lớp foreground/background/monochrome, cấu hình XML thích hợp phiên bản Android; không đổi hình heo hoặc tự sinh logo mới.
3. Splash dùng biểu tượng/branding phù hợp Android splash API, không nhét ảnh chụp 1080×1920 vào icon mask.
4. Port semantic theme thực tế v2 sang v1, centralize colors; MoneyText có dấu và số tabular. Trạng thái disabled/error/offline có độ tương phản phù hợp.
5. Bốn bottom destination chỉ icon, semantic label/tooltip đầy đủ; badge pending không che icon. Giữ route cũ cần cho deep link bằng alias nếu đổi URL.
6. Shared components có loading/error/empty/data riêng, không `.value ?? []` để coi lỗi là rỗng. Dùng sheet có bàn phím, safe area và text scaling đúng.
7. Cài đặt có lối vào Công nợ, Đầu tư, Lịch, Ghi chú, danh mục/tag/người, ngân hàng, giao diện, đồng bộ và tài khoản. Không hiển thị trả góp hoặc số dư ngân hàng.

**Test source cần viết:** navigation bốn icon/semantic labels; theme light/dark; sheet narrow/keyboard/large text; signed-out redirect/deep link không lặp.

## D. Task 3 — Schema/seed, Công nợ và reset chuẩn bị

**Sửa:** `linux/supabase/migrations/` (migration mới, không sửa lại SQL cũ đã áp dụng), `linux/supabase/tests/`, shared `record.dart`, `local_database.dart`, `finance_repository.dart`, `features/debts/debt_service.dart`, `core/utils/ledger.dart` và finance_apply liên quan.

### D1. Migration/seed
1. Đọc trigger/constraint thực tế; migration 006 đang chỉ cho behavior lending ở expense và ép purpose debt_disbursement, nên phải thay có chủ đích cho mô hình Công nợ hai chiều.
2. Tạo migration kế tiếp với tên rõ (`007_pmv_catalog_debt.sql` nếu 007 còn trống). Thêm trường/constraint/trigger và update RPC theo contract; giữ ownership, allowlist, foreign keys, receipt.
3. Seed đúng tất cả nhãn ở đặc tả, cả Thu/Chi. Seed idempotent; `finance_defaults` không tái sinh seed cũ sau sync.
4. Công nợ mỗi transaction chỉ một tag nghiệp vụ; ngân hàng có direction cố định nên chỉ cho action đúng chiều. Payment phải trỏ khoản cùng owner, currency và đúng lent/borrowed; loại completed khỏi picker.
5. Khởi tạo khoản Cho vay/Vay nợ liên kết đúng transaction nguồn, ID ổn định từ transaction. Thu nợ/Trả nợ tạo đúng một payment và một ledger transaction trong batch.
6. Bỏ chặn vượt số dư tại mọi tầng, không bỏ validation số tiền dương/hợp lệ. Cho số dư tính toán âm nếu vượt, không clamp thành 0 và không tự completed khi <=0.
7. Thêm hoàn tất thủ công/status đồng bộ. Lưu Hoàn tất không tự tạo giao dịch cân bằng và không sửa số gốc; lịch sử giữ nguyên.
8. Tổng quan chuyển sang tính cả purpose công nợ theo chiều, đúng một lần; thống kê vẫn loại transfer và future rows theo quy tắc hiện hành nếu còn.

### D2. Chuẩn bị reset, không thực thi
1. Tạo `linux/tool/reset_pmv.py` với mặc định dry-run, yêu cầu user UUID và cấu hình mục tiêu rõ ràng; tuyệt đối không log secrets.
2. Chỉ xóa bảng/rows v1 đã xác định và đúng owner; không xóa auth.users, schema qlt, bảng ngoài app hay schema public toàn bộ. SQL identifiers từ allowlist, tham số hóa UUID.
3. Xử lý receipts/defaults và trình tự FK đúng; transaction/rollback, xác minh row counts; actual mode phải explicit. Không hardcode hoặc đoán UUID chủ app.
4. Tạo `docs/pmv/reset-runbook.md`: xác định project/schema/user, dry-run, dừng writer app cũ, migration, reset, seed, đồng bộ local cache/outbox/native drafts, chống replay, kiểm tra rồi mở writer app mới.
5. Không thêm reset-on-start hoặc reset-on-version-change. Nếu cần local reset cho cutover, làm thao tác explicit và documented, không tự chạy khi app khởi động bình thường.

**Test source cần viết:** bốn action, overpayment được phép, amount invalid bị từ chối, owner/currency/direction sai bị từ chối; retry receipt không double insert; completed do nút; sum totals; seed lặp; reset dry-run không ghi và phạm vi allowlist.

## E. Task 4 — Thu chi, Biến động và undo

**Sửa:** shared `features/transactions/{transaction_form,transaction_screen,tag_suggestions}.dart`, `features/bank_import/`, `features/catalog/`, providers và repository; native inbox/bridge khi cần undo/capabilities.

1. Giữ native capture v1 trực tiếp, MB/VietinBank/BIDV/Techcombank và quyền opt-in. Không đưa cấu hình collector/admin v2 vào.
2. Native pending → phân loại → local transaction/tags/debt receipt/outbox commit → finish native draft. Crash/retry giữa hai bước chỉ hoàn tất lại native, không tạo trùng.
3. Form ngân hàng chỉ đọc amount/direction/time/source/original description; category required, tags theo danh mục, note optional. Nếu parser không đủ dữ liệu để duyệt an toàn, cho trạng thái cần xử lý thay vì tự đoán giá trị; ghi rõ policy trong contract.
4. Gợi ý 5 danh mục + Khác, rank riêng income/expense từ ledger thực; tie/default order ổn định. Khác là nút mở catalog, không phải category Chi khác/Thu khác.
5. Thêm tag/category inline giữ toàn bộ draft. Đổi danh mục xóa lựa chọn tag không tương thích; không tự đổi source ngân hàng.
6. Công nợ: Cho vay/Vay nợ chọn người; Thu nợ/Trả nợ có nhãn Chọn danh sách công nợ, hiển thị khoản đúng chiều đang active, chọn khoản rồi xác nhận. Manual amount editable; bank amount read-only.
7. Undo slot persistent gồm owner, draft ID, deadline; load lại slot khi khởi động. Ẩn mục và giảm count khi đang undo; Undo phục hồi; expiry hoàn tất native với retry bền vững. Discard mới finalize slot trước. Logout/owner change không phục hồi slot người cũ.
8. Không tự loại chuyển khoản nội bộ, không ghép hai notification; người dùng bỏ qua.
9. Manual Thu/Chi giữ offline-first, lọc/tháng/loại/danh mục/tag, tìm và detail. Không đặt ghi chú thành required để bù thiếu tag.

**Test source:** delayed finish/retry, undo trước/sau deadline/restart/discard liên tiếp/owner lifecycle; inline create draft; đúng danh mục gợi ý; công nợ không duplicate; empty/error/cache states và consistent count.

## F. Task 5 — Tổng quan, Công nợ, Đầu tư, Ghi chú

**Sửa:** `features/dashboard/`, `features/debts/debt_screen.dart`, `features/notes/notes_screen.dart`, catalog, router/settings. **Tạo:** `features/investments/investment_screen.dart` (hoặc tên hợp lý cùng vai trò).

1. Tổng quan theo UI v2, chọn tháng, thu/chi/net, biểu đồ, recent rows. Công nợ/Đầu tư nằm trong totals/charts như các khoản thu/chi; không có investment summary riêng và không bank balance.
2. Trang Công nợ hiển thị người/khoản, direction, gốc, thu/trả, chênh lệch và lịch sử; action Hoàn tất, nhóm Đã hoàn tất. Đừng thay mô hình danh mục/tag bằng bốn danh mục riêng.
3. Trang Đầu tư: lọc khoảng thời gian/tag, vốn bỏ vào, tiền nhận về cả gốc+lãi, chênh lệch và history; không tạo lot/portfolio/liên kết thu-chi, không gọi chênh lệch là lợi nhuận.
4. Trả sau chỉ category/tag payment; gỡ entry point, option, provider và schedule tạo installment. Chỉ xóa file sau kiểm tra callers; không sửa migration cũ để xóa dấu vết.
5. Giữ ghi chú/ghim, đưa vào Settings; không bổ sung alarm/calendar sync từ ghi chú.
6. Giữ source metadata ngân hàng khi sửa classification/note; sửa/xóa giao dịch có công nợ phải cập nhật liên kết nguyên tử, tránh payment orphan.

**Test source:** totals có debt/investment và không pending; debt completion/list picker; investment filter/all principal+interest; không có installment/balance UI; notes route/pin.

## G. Task 6 — Lịch, hai widget và bàn giao

### G1. Calendar source + app
**Tạo:** shared `features/calendar/{calendar_models,calendar_repository,calendar_providers,calendar_screen,calendar_settings}.dart`; Kotlin package `calendar/` bên cạnh banknotification, channel đăng ký tại MainActivity; manifest READ_CALENDAR. Có thể đổi tên file để hợp cấu trúc, ghi mapping trong report.

1. Repository typed interface calendars/instances; request permission từ người dùng khi vào Lịch, explicit denied/revoked state; không WRITE_CALENDAR.
2. Lọc đúng account_name minhvu2592005@gmail.com và account_type com.google; mặc định calendar visible/sync đang bật. Cho chọn từng calendar ID, dùng chung app/widget. Không đọc account khác rồi lọc ở UI.
3. Query Instances theo range để xử lý recurrence; event id/instance start stable; phân biệt all-day UTC và local timed; normalize clipping event nhiều ngày ở biên tháng.
4. Month grid theo ảnh đã duyệt: thứ Hai đầu tuần, ngày dương, tên event trong ô ngày, overflow +N, today/selected rõ. Header chọn/thay tháng; chọn ngày xem detail chỉ đọc; không nút + như app Samsung vì phạm vi read-only.
5. Count mỗi ngày từ instances thực (không double count event nhiều ngày trên cùng ngày); palette bounded tăng độ đậm. Ghi thresholds trong contract để app/widget khớp, dùng today marker độc lập shading.
6. ContentObserver/lifecycle/date/timezone change refresh có debounce, query ngoài UI thread và range bounded, không query toàn bộ lịch vô hạn. Không upload event lên cloud hoặc log event details.

### G2. Widgets
**Sửa:** banknotification/BankInboxWidget.kt, native widget resources/info/receivers. **Tạo:** CalendarWidgetProvider/renderer/data adapter và `res/layout`, `res/xml` tương ứng.

1. Biến động widget 2×2 count-only, source local inbox v1, count trừ slot undo; không dùng widget token/backend v2.
2. Calendar widget default span 4×2, layout tháng trái + selected date/events phải, nền dark translucent/rounded theo ảnh. Không lunar, không add action, ngày có event tăng màu theo count.
3. Chọn ngày trên widget cập nhật panel phải nếu khả thi với RemoteViews; chạm tiêu đề/event mở PMV Calendar theo ngày. App cold start/login giữ pending route và consume một lần. Không tất cả click đều mở Google Calendar ngoài app.
4. Dùng Calendar Provider/read permission native chung, selection settings cùng contract Dart; không cần Flutter engine liên tục chạy để render widget.
5. Handle no permission, no events, data stale/empty, midnight/timezone, resize và nhiều instance widget. PendingIntent identity khác nhau cho từng date/widget, không dùng extras bị ghi đè lẫn nhau.
6. Không công bố widget refresh SLA; OS có thể trì hoãn, phục hồi khi app resume/provider change.

### G3. Handoff source
Tạo `docs/pmv/agy-handoff.md` bao gồm:
- Worktree absolute path, branch, base commit và source v2 commit.
- Checklist task 1–6: implemented/partial/blocked, file mapping, pending TODO thực tế; không dùng completed cho stub.
- Những quyết định kỹ thuật, migration/reset scope, behavior/action codes, dependency/codegen cần thiết.
- Test files đã viết; đánh dấu NOT RUN cho mọi test/build chưa thực thi. Lệnh Codex cần chạy, env/deps thiếu.
- Không `.env`, DB DSN, signing passwords, raw bank/event dữ liệu trong report hoặc fixture; fixture synthetic.
- Danh sách file thay đổi và rủi ro cần Codex kiểm tra; không chỉnh production hoặc tuyên bố đã nghiệm thu.

**Test source:** calendar permission/recurrence/all-day/timezone/month layout/shading, selection shared app/native, widget intents/count and undo, delayed callback after logout. Không viết snapshot test lặp implementation để tăng số lượng.

## H. Task 7 — Codex, không giao Agy thực hiện

1. Review diff đối chiếu toàn bộ đặc tả; đặc biệt schema trigger/RPC 006, debt totals, idempotency, undo persistence, Calendar Provider ranges và native lifecycle.
2. Chạy analyze/tests shared + Android; Kotlin unit tests; SQL/RLS/reset tests trong môi trường cô lập. Lệnh dự kiến từ worktree:
   - `(cd linux/packages/finance_core && flutter analyze && flutter test)`
   - `(cd android && flutter analyze && flutter test)`
   - `(cd android/android && ./gradlew :app:testDebugUnitTest)`
   - SQL bằng công cụ database.py sau khi kiểm tra đích là môi trường test, không tự chọn .env production.
3. Sửa lỗi hoặc trả findings cho Agy; không đổi yêu cầu sản phẩm ngầm.
4. Build APK, kiểm tra signing/package/config, cài A54 phù hợp với quyền người dùng và đúng artifact. Không uninstall để né migration/signature lỗi.
5. Trước cutover/reset: xác định đúng user/project/schema v1, dry-run và phạm vi; dừng writer cũ, reset/migration có phối hợp, không chạm Auth/v2. Nếu quyền/phạm vi chưa đủ thì hỏi đúng một vấn đề cần thiết.
6. Nghiệm thu A54: bốn tab, light/dark/text size, manual/notification, công nợ bốn action/overpay/completed, đầu tư, undo, offline/retry, lịch và hai widget Home Screen cold/warm.
7. Bàn giao kết quả thực tế có version/hash, commands/results, screenshots đã kiểm soát dữ liệu, giới hạn chưa kiểm chứng. Không suy live notification từ unit tests.

## I. Quy tắc xử lý thiếu thông tin

Các chi tiết mỹ thuật nhỏ (spacing, ngưỡng shading, vị trí icon) được quyết định theo mẫu và ghi vào report. Không tự thêm feature. Nếu thiếu một quyết định nghiệp vụ làm đổi luồng, hỏi người dùng đúng một vấn đề mỗi lần. Không reset DB, đổi kiến trúc sang v2 hoặc xóa dữ liệu người dùng để vượt blocker triển khai.
