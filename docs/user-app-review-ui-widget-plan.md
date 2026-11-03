# Review và kế hoạch triển khai User App — Android/iOS

Ngày review: 05/10/2026. Người thực thi tiếp theo: Antigravity (Agy). Người review cuối: Codex.

## 1. Phạm vi và mức độ xác minh

Codex đã đọc diff của toàn bộ 17 file tracked được sửa, các file bridge/test mới, báo cáo bàn giao, code backend snapshot/widget liên quan và ảnh Samsung/iOS. Đã chạy lại finance_core: 84/84 pass; api_client: 8/8 pass; user_app: 1/1 pass; flutter analyze tại user_app không có issues; git diff --check pass. Test xanh xác nhận các trường hợp hiện có, chưa chứng minh toàn bộ race condition hoặc widget Home Screen hoạt động đúng.

Review này không tái diễn thao tác trên điện thoại, không phân loại thêm giao dịch production. Kết quả E2E do Agy báo cáo cần giữ nhãn là bằng chứng của lượt trước. Không xem screenshot của một màn hình là bằng chứng cho offline, không mất dữ liệu, cancellation hoặc cleanup token.

Hướng thiết kế được chọn: nền trung tính, xanh teal trầm làm điểm nhấn, phân cấp thông tin rõ, ít viền và ít mảng màu sáng. Giữ 4 tab Tổng quan / Thu chi / Biến động / Cài đặt. Widget 2×2 mặc định hiển thị **số biến động chờ phân loại**, không hiển thị số tiền hay số tài khoản.

## 2. Findings cần xử lý

### R1 — P1: Gán sai tài khoản khi không có kết quả khớp

`packages/finance_core/lib/core/database/local_database.dart`, đoạn 306–322: `orElse: () => bankBindingList.first` gán giao dịch vào ngân hàng đầu tiên nếu không tìm thấy binding. Giao dịch thủ công thiếu bank snapshot cũng đi vào nhánh này. Hai tài khoản cùng hậu tố bị chọn theo thứ tự danh sách. Điều này làm sai số dư theo tài khoản mặc dù tổng thu chi có thể đúng.

Sửa: ưu tiên ID liên kết có nguồn gốc xác thực; chỉ suy ra từ bank code + account khi kết quả duy nhất. Không khớp/khớp nhiều thì giữ trạng thái chưa xác định, không đoán. Không gán tài khoản ngân hàng cho giao dịch thủ công. Xử lý binding bị xóa/đổi tên và tài khoản synthetic cũ, không xóa tài khoản người dùng tự tạo. Phân biệt rõ số dư sổ thu chi với số dư ngân hàng thực; opening_balance=0 không thể chứng minh số dư ngân hàng.

Test: nhiều ngân hàng; hai tài khoản cùng ngân hàng/hậu tố; không khớp; thiếu snapshot; manual transaction; binding bị gỡ; không đổi account_id hợp lệ.

### R2 — P1: Logout còn cửa sổ đua với login và cleanup

`app/providers.dart`: signOut chuyển session thành null trước khi đóng workspace rồi mới gọi auth logout và clear token. Login đã có thể hiện ra trong lúc cleanup chờ `_flight`. Request logout không có timeout ở ApiClient; nếu cleanup database ném lỗi, các bước clear credential phía sau không được bảo đảm. Nếu người dùng login nhanh, logout cũ có thể đọc/xóa token mới. Cờ generation hiện chỉ kiểm soát invalidate cuối hàm, không bảo vệ các bước xóa token.

Sửa bằng một lifecycle rõ ràng restoring/authenticated/signingOut/signedOut: capture session identity cũ, chặn login mới cho đến khi local cleanup hoàn tất, timeout/cancel request thu hồi server, cleanup local trong finally, dùng session generation cho mọi callback. Không biến lỗi xóa secure storage thành “logout thành công”; retry/hiển thị trạng thái thích hợp. Không để callback getCurrentUser cũ phục hồi user sau signOut. Tái hiện các khả năng này bằng controllable Future trước khi sửa.

`SyncEngine.stop()` chỉ chờ `_flight`; các callback inbox async không được track, cancel subscription không đồng nghĩa chờ callback đã vào DB hoàn tất. Đoạn catch quanh `super.notifyListeners()` che lỗi thay vì chứng minh lifecycle an toàn. Theo dõi/đợi mọi DB writer trước khi đóng DB; dispose idempotent, listeners detach đúng lúc; không nuốt mọi exception.

Test: logout khi GET /me, snapshot, realtime DB write đang chờ; teardown ném lỗi; logout timeout; double logout đồng thời; login ngay sau logout; đổi user A→B; token B không bị logout A xóa; không DB write sau close.

### R3 — P1: Widget có thể trở lại logged-in sau logout

`app/app.dart:117–123`: clear widget trong build, nhưng listener pending gọi update count bất kể auth/loading/error. Android `WidgetCache.setPendingCount()` còn đặt is_logged_in=true. `WorkspaceController.build()` gửi credentials bằng unawaited task không kiểm tra generation sau await. Android clearWidget không hủy unique periodic worker; response cũ có thể ghi count sau clear. iOS timeline trả isLoggedIn=true cho mọi failure, kể cả 401 đã clear credentials.

Sửa: widget state machine gắn owner + session generation + revision. Side effect ở lifecycle controller/listener, không ở build. Chỉ cập nhật count với authenticated successful data; lỗi mạng giữ cache và đánh dấu stale, không chuyển count thành 0. Native bỏ mọi response sai generation. Logout clear credential/count, cancel work, reload widget; callback cũ không được hồi sinh state. iOS 401/403 là expired/loggedOut, không phải offline logged-in.

Test bằng fake channel/worker/timeline và response bị trì hoãn; screenshot Home Screen sau logout và sau response cũ. Không chỉ test clearWidget đã được gọi.

### R4 — P1: App session token bị sao chép vào widget preferences

`providers.dart` đang lấy token chính và gửi qua bridge; Android lưu trong SharedPreferences thường, iOS trong App Group UserDefaults. Backend đã có POST /widget-token và widget summary, nên không cần cấp toàn bộ app session cho widget.

Sửa: dùng widget credential quyền tối thiểu; Android lưu credential được bảo vệ bằng Keystore, iOS shared Keychain access group phù hợp. Preferences chỉ chứa cache không nhạy cảm. Audit endpoint revoke hiện tại: DELETE /widget-token đang xác thực bằng app session nhưng lấy cùng Authorization token để revoke, cần test thu hồi đúng widget token của đúng owner. Nếu sửa contract backend là bắt buộc, giới hạn vào widget auth và thêm integration tests; không mở rộng vào Collector. Dọn bản token đã tồn tại trong legacy preferences khi migrate. Không log token.

### R5 — P1/P2: Bật native inbox không tồn tại và nuốt lỗi ghi

`bank_draft_repository.dart`: bỏ feature flag BANK_INBOX_NATIVE_ENABLED, bật cho mọi Android, nhưng MainActivity hiện chỉ đăng ký widget channel; không có implementation `personal_finance/bank_inbox` ở app User hiện tại. `_call()` bắt mọi lỗi rồi trả null, khiến `finish()` lỗi trông như thành công; `settings()` lại force unwrap null. FakeBankInbox trong test override finish, nên test xanh không kiểm tra adapter production này.

Sửa: xác nhận kiến trúc Collector gửi biến động lên server là nguồn chính. Khôi phục gating/capability check cho native inbox không được hỗ trợ. Không đưa capture vào User App chỉ để làm test pass. Không nuốt lỗi mutation; MissingPlugin chỉ được xử lý có chủ đích ở optional capability. Nếu giữ local draft mode phải có native implementation, source rõ ràng, pagination và dedup, không dùng fallback im lặng.

### R6 — P2: Lỗi mạng hiển thị thành đã xử lý hết

`pending_bank_screen.dart` đọc `.value ?? []` rồi hiển thị All caught up, bỏ loading/error/retry của phiên bản trước. Khi offline/500 hoặc lần tải đầu, thông báo này sai. `hasRemote ? remote : local` còn ẩn toàn bộ local rows khi có remote.

Sửa: explicit loading/empty/error/offline-with-cache/success; empty chỉ khi request thành công và count=0. Nguồn remote/local không được tráo ngầm. Sau accept server thành công nhưng sync lỗi, báo “Đã duyệt; đang cập nhật dữ liệu”, không mời duyệt lại. Idempotency key phải ổn định khi retry cùng thao tác. Kiểm tra việc sync đang chạy sẵn: await sync() hiện chỉ join flight cũ, chưa bảo đảm snapshot sau accept; enqueue rerun hoặc barrier dựa revision.

### R7 — P2: Ngày giờ và dữ liệu snapshot bị làm đẹp bằng giá trị giả

`record.dart` trả DateTime.now() khi ngày không hợp lệ, tác động mọi caller chứ không riêng detail. `applySnapshot` mặc định amount=0 và tạo created/updated từ occurred_at hoặc hiện tại. Điều này tránh crash nhưng có thể hiển thị sai ngày/số tiền và thống kê.

Sửa: nullable parsing hoặc validation kết quả có lỗi; UI hiển thị “Không có thông tin”/ẩn metadata thiếu. Không tự nhận thời gian phát sinh là thời gian tạo/cập nhật. Validate amount chính xác theo tiền tệ, không âm thầm đổi dữ liệu lỗi thành 0. Audit `archived`/`is_archived` và các field canonical khi mapping.

### R8 — P1, cần test chứng minh: snapshot/migration không được làm mất pending edits

Snapshot xóa toàn bộ transactions/transaction_tags trước khi insert server data. Sync tiếp tục apply snapshot sau operation lỗi còn trong outbox. Migration xóa revision khiến full snapshot chạy lại nhưng chưa có test bảo toàn dirty records. Vì vậy tuyên bố “self-healing không mất thông tin” chưa được chứng minh.

Sửa/test: migrate fixture DB cũ có draft, pending operation lỗi, tags và offline edit; overlay dirty rows hoặc cơ chế merge có quy tắc, giữ idempotency. Đánh dấu format version sau migration thành công hoặc dùng marker pending/complete rõ ràng. Không xóa DB để vượt qua test. Logout hiện clearPrivate xóa cả outbox: xác định UX cảnh báo dữ liệu chưa đồng bộ và bảo toàn/loại bỏ có lựa chọn, không âm thầm mất ghi chép offline.

### R9 — P2: Deep link chưa có contract consume-once

Android getInitialRoute đọc Intent mà không consume; app gọi lại khi resumed nên có thể tự nhảy về Biến động sau khi người dùng đã đi tab khác. iOS chỉ bổ sung openURLContexts (warm); cần kiểm thử cold scene connectionOptions và thời điểm Flutter handler chưa sẵn sàng. onDeepLink có channel chưa đồng nghĩa Dart handler đã nhận.

Sửa: một nơi giữ pending route, consume-once/ack, allowlist route, giữ qua login và chọn ngôn ngữ, clear đúng lifecycle. Test cold/warm/foreground/locked/loggedOut rồi login; mở app bình thường lần sau không bị redirect cũ.

### R10 — P1 vệ sinh repo/bằng chứng; không phải toàn bộ do patch mới gây ra

`apps/user_app/signing/credentials.json` chứa mật khẩu ký số và đang tracked trong Git. Không lặp lại giá trị trong report. Chuyển cấu hình bí mật ra version control bằng quy trình giữ nguyên local key và khả năng cập nhật APK; đánh giá exposure lịch sử, không tự rewrite history hoặc thay signing identity.

Báo cáo nói artifacts không có dữ liệu nhạy cảm nhưng screenshot/test fixture có mô tả ngân hàng, tên và số tài khoản thật. Thay fixture bằng dữ liệu giả; bản evidence chia sẻ cần redact. Không sửa bản gốc để giả bằng chứng. Báo cáo chưa có đủ bằng chứng widget Home Screen, iOS offline, dark mode, text scaling. Android tắt Wi-Fi chưa chứng minh offline nếu mobile data còn bật. APK bàn giao trước các sửa snapshot có thể cũ: build lại sau cùng, hash và version phải khớp bản cài nghiệm thu.

## 3. Design specification: dịu mắt, rõ tiền và hành động

### 3.1 Tokens

Dùng ThemeExtension/ColorScheme semantic tập trung cho Flutter và bộ token tương ứng native widget. Không rải màu hardcode trong màn hình. Bảng dưới là palette khởi điểm; Agy đo contrast trên từng cặp thực tế và điều chỉnh khi cần.

| Token | Light | Dark |
|---|---|---|
| canvas | #F4F5F3 | #121716 |
| surface | #FCFCFA | #1B2321 |
| surfaceRaised | #ECEFED | #25302C |
| textPrimary | #202A26 | #E4EAE6 |
| textSecondary | #59675F | #A8B7AE |
| border | #D8E0DA | #36443D |
| primary | #356A59 | #9BC8B2 |
| primaryContainer | #E0ECE5 | #29483C |
| income | #356D59 | #9AC6AE |
| expense | #A64F49 | #DCA49C |
| warning | #805F28 | #D4BB86 |

- Dark mode dùng than xanh rất nhẹ, không đen tuyệt đối + trắng chói. Light mode dùng off-white, tránh nền xám chữ nhạt gây khó đọc.
- Primary bright chỉ ở icon/text hoặc CTA tập trung; list Biến động dùng tonal/outline, tránh nhiều pill xanh sáng lớn.
- Màu biểu đồ giới hạn 4–5 màu muted theo theme; label và shape/legend giúp phân biệt, không chỉ dựa đỏ/xanh.
- Chuẩn nghiệm thu contrast: text thường ≥4.5:1, chữ lớn ≥3:1, control/indicator thiết yếu ≥3:1. Ghi cặp màu và phép đo trong report.
- Font hệ thống hỗ trợ đầy đủ tiếng Việt; title 22–26, section 18–20, body 15–16, secondary 13–14; tiền lớn 28–32, tabular figures. Không tự thu font toàn app để hết overflow.
- Spacing 4/8/12/16/24/32; margin mobile 16–20; card radius 16, field 12; border nhẹ, elevation thấp; không gradient/neon/glow.
- Vùng bấm ≥48dp Android và ≥44pt iOS. Text scale 1.0/1.3/2.0; wrap/reflow khi lớn. Respect reduced motion; transition 150–220ms, không shimmer liên tục.

### 3.2 App shell và navigation

- Giữ 4 tab, badge Biến động đọc từ nguồn authoritative; badge lỗi không biến thành 0.
- Navigation bar nền trung tính, indicator tonal nhỏ; SafeArea đúng Android gesture/3-button và iOS home indicator.
- CTA thêm giao dịch chỉ hiện khi phù hợp Tổng quan/Thu chi; bố trí bottom inset để hàng cuối không bị che. Không đặt CTA này trên Login, Cài đặt hoặc trang duyệt gây nhiễu.
- Giữ scroll/filter của từng tab. Back gesture/system back đúng kỳ vọng; app bar native-adaptive về alignment/hành vi nhưng dùng chung design system.
- Global search và search trong Thu chi cần phân biệt phạm vi, tránh hai icon tìm kiếm không rõ công dụng.

### 3.3 Tổng quan

- Loại bỏ metric width=230 cố định đang gây cột thẻ hẹp và khoảng trống phải trên Samsung.
- Header ngắn: “Tháng 10, 2026”, bấm mở month picker; previous/next có semantics.
- Một summary card full-width: Chênh lệch thu chi là số chính, Thu nhập/Chi tiêu là hai số phụ cân đối. Không gọi chênh lệch tháng là “Số dư tài khoản”.
- Tỷ lệ tiết kiệm là dòng thông tin phụ kèm giải thích; income=0 hiển thị “Chưa đủ dữ liệu”, không Infinity/NaN. Giá trị âm không dùng nguyên nền đỏ.
- Biểu đồ ngày compact; top danh mục dạng progress/bar + số tiền đọc được. Mục chi tiết expand hoặc màn hình riêng; không ép mọi chart lên đầu.
- Dữ liệu 0 có empty state nhẹ và hành động thêm giao dịch; sync lỗi hiển thị dữ liệu đã lưu + thời điểm cập nhật.

### 3.4 Thu chi và chi tiết

- Search một dòng; segmented “Tất cả / Thu / Chi”; nút “Bộ lọc” mở sheet cho account/category/tag/date, badge số filter và “Xóa lọc”. Bỏ dãy dropdown rộng bị cắt nửa ô.
- Group theo ngày. Row: icon danh mục nhỏ, tiêu đề dễ hiểu 1–2 dòng, metadata ngân hàng/thẻ 1 dòng, số tiền căn phải đủ nổi bật. Mô tả ngân hàng raw chỉ 1–2 dòng có ellipsis và mở full trong detail.
- Số tiền không bị cắt: text lớn chuyển sang layout dọc. Format tiền theo locale, dấu +/− nhất quán; không chỉ dùng màu truyền đạt thu/chi.
- Detail sheet full-width/scrollable: amount và category trước; thông tin tài khoản đã mask, thời gian phát sinh, tags/note sau; raw bank text expand/copy có chủ đích.
- Không bịa nhãn mô tả/nội dung giao dịch; metadata không có thì ẩn hoặc ghi rõ chưa có.

### 3.5 Biến động và phân loại

- Header “Cần phân loại” + count, nguồn/last updated nhỏ. Empty success, loading, error, offline cache riêng.
- Card thấp hơn hiện tại: số tiền nổi bật, ngân hàng + giờ, mô tả rút gọn; một nút tonal “Phân loại”, secondary “Bỏ qua” không nổi ngang primary.
- Sheet review: giữ amount/time readonly; category, tags thuộc category, ghi chú; CTA đáy “Xác nhận”, tránh keyboard che. Đánh dấu trường bắt buộc và inline validation.
- Disable double submit; khi server accepted nhưng refresh lỗi, hiển thị trạng thái đã xác nhận và retry refresh. Không tạo operation mới để lặp mutation đã thành công.
- Undo chỉ hiển thị nếu backend/queue thực sự có khả năng hoàn tác; không xây toast hứa hoàn tác nhưng không thực thi.

### 3.6 Auth, Cài đặt và màn hình phụ

- Login bố cục gọn, brand “Quản lý Tao”, field username/password có autofill/keyboard action/show-hide; lỗi inline rõ ràng và không reset nội dung người dùng khi network lỗi.
- Restoring session khác signed-out, không nháy Login trong mỗi startup. Signing out có progress ngắn, ngăn gửi lại/login chồng.
- Cài đặt chia nhóm Tài khoản / Giao diện / Dữ liệu / Widget / Thông tin. Theme System–Light–Dark; language; privacy masking; sync status và retry dễ hiểu. Logout ở cuối, destructive style vừa phải.
- Debt, Notes, Catalog, Search dùng cùng tokens/spacing/empty/error states. Không dừng redesign ở bốn screenshot.
- Thêm trang “Widget màn hình chính”: preview 2×2, mô tả count-only, hướng dẫn Android và iOS đúng nền tảng. Android nút thêm nếu launcher hỗ trợ pin; iOS hướng dẫn Widget Gallery.

## 4. Widget 2×2: hoàn thiện native implementation và khả năng cài

### Hiện trạng

Android đã khai báo targetCellWidth=2, targetCellHeight=2 trong `res/xml/bank_inbox_widget.xml`. iOS InboxWidget đã hỗ trợ systemSmall/systemMedium. Có code không đồng nghĩa extension được discover/render/add thành công. Cần điều tra nguyên nhân người dùng chưa thấy widget trước khi thêm target/provider trùng.

### Contract và thiết kế

- Android 2×2 cells, iOS systemSmall; không hardcode cùng pixel kích thước giữa hai hệ điều hành.
- Nội dung: icon inbox + “Biến động”; count lớn; “cần phân loại”; trạng thái cập nhật nhỏ. 0: “Đã xử lý hết”. Loading chưa có cache: “Đang cập nhật”. Offline có cache: count cuối + “Chưa cập nhật”. Logged out/expired: icon khóa + “Đăng nhập để xem”.
- 99/999/9999, text lớn, locale EN/VI phải fit; semantics đọc count đầy đủ. Không số tiền, số tài khoản, tên người gửi, payload raw hoặc nút duyệt trực tiếp trên Home Screen.
- Tap toàn widget mở /pending, auth/language gate xong phải tiếp tục đúng route. Không nhảy route lại ở lần resume sau.
- Native cache gồm owner/session generation, pending count, revision, fetchedAt, status; không chứa full transaction hoặc app session token.
- Cập nhật theo app sync/accept/login/logout và native background budget; không hứa refresh chính xác mỗi 15 phút. Hiển thị trạng thái stale dựa fetchedAt thật.

### Android

- Audit manifest receiver, AppWidgetProviderInfo, release resource shrinking, label/icon/preview, package cài đúng bản mới.
- Giữ RemoteViews hiện có nếu đáp ứng; không chuyển sang Glance chỉ vì redesign.
- Bổ sung previewLayout/image phù hợp API, dimension/resize constraints, day/night resources, rounded background và paddings thích ứng launcher.
- Test Add widget bằng Samsung One UI thật, grid 4/5 cột nếu thiết bị cho phép; size 2×2 và resize không mất chữ; nhiều instance đồng bộ.
- WorkManager unique job phải có cancel-on-logout, session generation guard và retry có backoff. Pin widget theo capability launcher; hướng dẫn long-press fallback.

### iOS

- Audit extension có trong Runner.app/PlugIns, @main bundle, supportedFamilies, entitlements App Group, shared Keychain, signing và Widget Gallery.
- Asset Color("WidgetBackground") phải tồn tại trong extension hoặc thay bằng semantic color có light/dark; không phụ thuộc asset Runner vô tình không được bundle.
- Dùng containerBackground(for: .widget) khi OS hỗ trợ, fallback tương thích deployment target. Test widget tint/rendering modes của runtime đang có; không ép nền khiến mất readability.
- Hoàn thiện placeholder/getSnapshot/getTimeline riêng trạng thái, 401/403 clear, completion đúng một lần, session generation guard response cũ.
- Đồng bộ version/build của extension từ cùng nguồn với Runner, không hardcode 1.0.0/1 mãi.
- Thêm widget systemSmall thật lên Home Screen Simulator; screenshot small trong light/dark/loggedOut/offline. Nếu provisioning/app group chỉ xác nhận trên máy thật được thì ghi rõ giới hạn, không tuyên bố production-ready.

Tài liệu tham chiếu chính thức:
- Android layout/sizing: https://developer.android.com/develop/ui/views/appwidgets/layouts
- Apple widget families: https://developer.apple.com/documentation/widgetkit/widgetfamily
- Apple widget background: https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background

## 5. Thứ tự thực thi giao cho Agy

1. Chụp baseline git status/diff, ghi version artifact, giữ nguyên thay đổi của người dùng. Tạo ledger checklist R1–R10: confirmed/fixed/tested/deferred với bằng chứng. Không chỉ copy kết luận review; viết test tái hiện trước các rủi ro concurrency.
2. Xử lý R1/R2/R3/R4/R8 và secret hygiene trước; sửa R5/R6/R7/R9. Dùng fake backend/DB và tài khoản test riêng; không chỉnh tiếp giao dịch thật để tạo screenshot.
3. Tạo `docs/user-app-design-spec.md`: tokens, component states, bố cục và decisions. Implement một vertical slice Tổng quan + Thu chi light/dark ở 390 logical pixels, chụp trước/sau, tự kiểm tra contrast/text scaling rồi áp dụng toàn app.
4. Xây shared components: AppPage, SectionHeader, SummaryCard, MoneyText, TransactionRow, FilterSheet, AsyncContent, SyncBanner, PendingCard, SettingsGroup. Dùng API phù hợp repo, không buộc tên lớp nếu đã có tương đương.
5. Hoàn thiện các màn hình, responsive và platform gestures. Logic thu chi không thay theo trang trí UI.
6. Hoàn thiện widget contract/secure storage, native 2×2 Android/systemSmall iOS, trang hướng dẫn thêm widget; nghiệm thu trong Gallery/Home Screen thật.
7. Chạy test tự động, build release mới, cài đúng artifact trên Samsung và Simulator, chạy E2E đầy đủ; chỉ dùng dữ liệu synthetic cho mutation.
8. Bàn giao source uncommitted, report và evidence đã làm sạch để Codex review. Không tự deploy backend production hoặc đổi signing key; nếu cần rollout backend widget contract thì chuẩn bị patch/test và ghi bước triển khai riêng.

## 6. Nghiệm thu và test matrix

### Tự động

- Analyze và tests cả user_app, finance_core, api_client; regression Collector do shared packages/build tool thay đổi, không sửa UI Collector.
- Race tests bằng Completer/delayed mock cho R2/R3; native channel production adapter tests, không chỉ fake repository overrides.
- Snapshot fixtures manual/bank/multi-account/invalid dates/currency/archived tags/dirty outbox/migration; đối chiếu ledger trước và sau đồng bộ, không mất pending edits.
- Widget native tests count parsing, empty/error/auth expired, owner switch, stale response, cold/warm link và consume-once.
- Golden/widget tests cho light/dark, width 320/360/390/430 và tablet nếu supported, text scale 1/1.3/2.0; không cố định height khiến chữ bị cắt. Data có số tiền dài, bank description dài, 0/1/100 giao dịch.
- Secret scan bao gồm tracked config/fixtures/text artifacts, không chỉ Dart; asset screenshots/video được kiểm tra/redact riêng.

### Thiết bị

- Samsung thật: xác nhận device ID/version; build signed release/cài đè giữ dữ liệu, một test migration thực. Không uninstall trước khi bảo toàn unsynced data.
- iPhone Simulator: build app, native widget tests, Home Screen install; device release/archive unsigned chỉ chứng minh compile/archive, không chứng minh signing/TestFlight.
- Mỗi nền tảng: login, navigation, form validation, scroll/filter, background/resume, cold relaunch, logout ×3, relogin; offline thật có request thất bại được chứng minh; change theme/language/text size.
- Widget: 0/nhiều/stale/offline/expired/loggedOut, login user khác, app killed, Home Screen tap cold/warm, logout khi worker đang trả response. Không còn count/user cũ sau logout.
- Biến động synthetic accept/discard: pending badge, overview, transactions và widget count nhất quán; retry không tạo duplicate.
- Visual acceptance: thẻ full-width/cột hợp lý, số tiền đọc trước raw text, không clipping/overflow, CTA không che hàng cuối, không chớp nền trắng trong dark mode, contrast đạt tiêu chí, giảm mảng primary sáng lặp lại.

### Bàn giao

Tạo `artifacts/user-app-ui-widget-<date>/report.md` gồm: findings và fix theo R-ID; file/dòng quan trọng; test thực chạy + exit code; command/log đã redact; app version/hash của APK cuối; widget screenshots trên Home Screen mỗi OS; trước/sau từng màn hình light/dark; coverage thiếu và blocker production. Phân biệt rõ tự động đã pass, E2E đã thao tác, và chưa test.

Thêm `docs/codex-review-handoff.md` tóm tắt các quyết định có rủi ro: auth/session ordering, widget token revoke, native callback generation, snapshot merge/outbox, migration và signing. Không kết luận “an toàn tuyệt đối”, “fix triệt để” khi thiếu test tương ứng.

Kết thúc thiết bị ở trạng thái logout đã xác minh, widget logged-out; không commit, không xóa artifact gốc hoặc dữ liệu người dùng. Bản sao chia sẻ chỉ chứa fixture giả/masked.
