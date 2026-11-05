# Bàn giao giao diện Quản lý PMV (UI Refresh cho Samsung A54)

## 1. Hướng thiết kế và các thay đổi chính

### Phong cách thiết kế
- **Android Material 3 & Samsung One UI**: Đường nét hiện đại, bo góc đồng bộ (12–16dp cho card/container, 20–24dp cho dialog/widget), phân cấp thông tin rõ ràng, tối ưu hoá thao tác một tay trên Samsung Galaxy A54.
- **Brand Kit Alignment**:
  - Deep Teal `#005E5D` làm màu chủ đạo (Primary Accent).
  - Mint `#EFFCF9` / `#F4FAF9` làm nền sáng nhẹ nhàng, dịu mắt.
  - Brand Navy `#071F31` làm màu chữ chính (Light) và màu nền bề mặt (Dark/Widget).
  - Brand Green `#42C245` / `#00796B` cho Thu nhập (Income).
  - Brand Gold `#ECB02E` cho cảnh báo, điểm nhấn và highlight biểu đồ.
  - Expense Red `#BF360C` tương phản cao nhưng không gắt.
- **Số tiền & Đọc số**:
  - Toàn bộ số tiền đều bật `fontFeatures: [FontFeature.tabularFigures()]` giúp số liệu thẳng hàng, dễ so sánh trực quan.
  - Kích thước chữ số tiền được phóng lớn ở các vị trí trọng tâm (Tổng dòng tiền, Thẻ biến động, Thẻ công nợ, Chi tiết giao dịch).
- **Công thái học (Ergonomics)**:
  - Vùng chạm tối thiểu 44–48dp cho tất cả nút bấm, icon button, list tile, filter chip.
  - Trên thiết bị di động, các form tạo/sửa dài chuyển sang dạng Fullscreen Dialog với thanh tiêu đề cố định, nút Huỷ (bên trái) và nút Lưu (bên phải trên cùng), bàn phím ảo hiển thị không bị che khuất nút Lưu.
  - Chuyển đổi loại giao dịch (Chi tiêu / Thu nhập / Chuyển khoản) và loại công nợ (Cho vay / Vay nợ) từ Dropdown sang Segmented Button / Custom Type Selector trực quan, thao tác 1 chạm.

---

## 2. Danh sách màn hình, component và file đã sửa

| STT | File | Nội dung thay đổi |
|---|---|---|
| 1 | `lib/app/theme.dart` | Hệ thống màu `AppThemeColors` (Light/Dark theo Brand Kit), `ThemeData` hoàn chỉnh với `TextTheme`, `AppBarTheme`, `NavigationBarTheme`, `FilledButtonTheme`, `InputDecorationTheme`, `CardTheme`, `BottomSheetTheme`, `DialogTheme`. |
| 2 | `lib/app/components.dart` | `SummaryCard` hiện đại hiển thị dòng tiền ròng + 2 ô Thu/Chi; `SectionHeader` không dùng uppercase gượng gạo; `StatMetricTile` cho dashboard; `TransactionLeadingIcon` chuẩn Material 3; `DateGroupHeader` cho danh sách ngày. |
| 3 | `lib/app/widgets.dart` | `EmptyState` mới với avatar tròn và icon rõ ràng; `FormDialog` hỗ trợ hiển thị Fullscreen trên màn hình hẹp (mobile) giúp cuộn mượt và tiếp cận nút Lưu khi mở bàn phím; `RecordPicker` hoàn thiện label tiếng Việt. |
| 4 | `lib/app/router.dart` | `NavigationBar` 4 tab chuẩn One UI (Tổng quan, Thu chi, Biến động, Cài đặt): ẩn nhãn văn bản (icon-only), giữ nguyên tooltip và accessibility label; badge đếm thông báo ngân hàng; `MoreScreen` cải tiến giao diện. |
| 5 | `lib/features/dashboard/dashboard_screen.dart` | Bố cục Tổng quan: MonthSelector, SummaryCard, hàng chỉ số phụ (Tỉ lệ tiết kiệm, Cho vay còn lại, Vay nợ còn lại), biểu đồ chi tiêu ngày, thanh tiến độ phân bổ danh mục & thẻ, danh sách giao dịch gần đây có icon avatar và tabular numbers. |
| 6 | `lib/features/dashboard/spending_chart.dart` | Biểu đồ cột chi tiêu theo ngày với bo góc mềm mại, highlight ngày được chọn bằng màu Brand Gold, số tiền ngày cao nhất và nhãn ngày trực quan. |
| 7 | `lib/features/dashboard/category_chart.dart` | Biểu đồ tròn (donut chart) phân bổ danh mục với màu sắc phân biệt rõ, số tiền và tỉ lệ phần trăm tabular figures. |
| 8 | `lib/features/transactions/transaction_screen.dart` | Màn hình Thu chi: bộ lọc ngang thu gọn dạng chip/dropdown nhỏ gọn, ô tìm kiếm có icon, danh sách nhóm theo ngày với header ngày rõ ràng, tile giao dịch có icon hướng tiền và số tiền lớn, `TransactionDetail` dialog. |
| 9 | `lib/features/transactions/transaction_form.dart` | Form giao dịch: Segmented Button chọn loại (Chi / Thu / Chuyển), ô nhập tiền lớn font 28sp tabular, chọn ngày giao dịch dạng card, khu vực hành động công nợ (Cho vay, Trả nợ, Thu nợ, Vay nợ), chọn người / chọn khoản nợ, tag 'Mua chung', danh mục & thẻ. |
| 10 | `lib/features/bank_import/pmv_bien_dong_screen.dart` | Tab Biến động: banner hoàn tác 3 giây, thẻ `_DraftCard` bo góc 16dp có badge phân biệt loại tiền vào/ra, ngân hàng, thời gian; form phân loại dạng bottom-sheet hiển thị container số tiền nổi bật và chip danh mục Top-5 + nút Khác. |
| 11 | `lib/features/bank_import/bank_import_settings.dart` | Cài đặt import ngân hàng: cấu hình nhóm dạng card, trạng thái quyền thông báo, dịch vụ kết nối nền (Listener Service), danh sách ứng dụng ngân hàng kèm switch và dropdown chọn tài khoản mặc định. |
| 12 | `lib/features/debts/debt_screen.dart` | Màn hình Công nợ: nút Tạo khoản nợ nổi bật, thẻ `_DebtCard` hiển thị icon phân biệt Cho vay/Vay nợ, số dư còn lại (hỗ trợ hiển thị cảnh báo khi trả vượt gốc), hạn trả/ngày giao dịch; form tạo/sửa công nợ; dialog chi tiết `DebtDetail` với lịch sử thu/trả nợ. |
| 13 | `lib/features/investments/investment_screen.dart` | Màn hình Đầu tư: chip chọn kỳ thời gian (Tất cả, Năm nay, Tháng này), filter chip thẻ, thẻ tổng quan vốn bỏ vào vs tiền nhận về (gốc+lãi) và chênh lệch lãi/lỗ ròng, lịch sử giao dịch đầu tư. |
| 14 | `lib/features/notes/notes_screen.dart` | Màn hình Ghi chú: thanh tìm kiếm + nút thêm mới, danh sách thẻ ghi chú hỗ trợ ghim (pin), gắn người liên quan, ngày nhắc nhở; form tạo/sửa ghi chú đầy đủ. |
| 15 | `lib/features/catalog/catalog_screen.dart` | Quản lý danh mục, thẻ, tài khoản, người liên quan: icon đại diện cho từng loại thực thể, hiển thị số dư tài khoản, chi tiết tài khoản `AccountDetail`, form tạo/sửa đồng nhất. |
| 16 | `lib/features/calendar/calendar_screen.dart` | Lịch tháng Google Calendar: tuần bắt đầu từ Thứ Hai, shading màu ngày theo số lượng sự kiện (0 việc: trong suốt, 1–2: 15%, 3–5: 40%, 6+: 70%), vòng tròn đánh dấu ngày hôm nay, panel chi tiết ngày bên dưới hiển thị danh sách sự kiện kèm giờ và chấm màu lịch. |
| 17 | `lib/features/calendar/calendar_settings.dart` | Cài đặt lịch Google: danh sách tài khoản và lịch kèm checkbox, màu sắc của từng lịch. |
| 18 | `lib/app/settings.dart` | Tab Cài đặt: card người dùng Supabase, nhóm chức năng PMV, nhóm danh mục & dữ liệu, nhóm ngân hàng, nhóm tùy chỉnh giao diện (Sáng/Tối/Hệ thống), ngôn ngữ, trạng thái đồng bộ và nút đăng xuất. |
| 19 | `lib/app/search.dart` | Hộp thoại tìm kiếm toàn cục (Ctrl+K): hỗ trợ fullscreen trên mobile, tìm kiếm nhanh giao dịch, công nợ, ghi chú, người liên quan, danh mục với icon phân loại. |
| 20 | `lib/features/auth/auth_screen.dart` | Màn hình đăng nhập/đăng ký: logo icon heo tiết kiệm brand kit, nhận diện thương hiệu Quản lý PMV, ô nhập liệu hiện đại. |
| 21 | `lib/app/language.dart` | Màn hình chào mừng chọn ngôn ngữ (LanguageWelcomeScreen) với radio cards hiện đại. |
| 22 | `android/.../res/layout/bank_inbox_widget.xml` | Widget Biến động 2×2: nhãn tiếng Việt "Biến động", trạng thái "Đã xử lý hết", nút "Mở Biến động →". |
| 23 | `android/.../res/drawable/inbox_background.xml` | Nền widget Biến động bo góc 24dp, màu brand navy `#071F31` viền teal. |
| 24 | `android/.../res/drawable/calendar_widget_bg.xml` | Nền widget Lịch 4×2 bo góc 24dp, màu tối mờ `#D9071F31` viền teal. |

---

## 3. Những thay đổi về trạng thái hoặc tương tác trình bày cần chú ý

1. **FormDialog Fullscreen trên màn hình di động**:
   - `FormDialog` trong `widgets.dart` đã được cấu hình tự động nhận diện `MediaQuery.sizeOf(context).width < 600`. Trên điện thoại (như Samsung A54), dialog sẽ bung toàn màn hình (Fullscreen Dialog) với AppBar có nút đóng (X) và nút Lưu ở góc trên bên phải. Điều này giải quyết triệt để lỗi bàn phím che khuất nút Save thường gặp trên Android.
2. **Segmented Button thay cho Dropdown Loại giao dịch**:
   - Trong `transaction_form.dart`, loại giao dịch (Chi tiêu / Thu nhập / Chuyển khoản) sử dụng hàng 3 nút bấm liền nhau (`_TypeButton`), phản hồi thị giác tức thì bằng màu sắc tương ứng (Đỏ / Xanh / Teal).
3. **Hiển thị số tiền trả nợ vượt gốc**:
   - Trong `debt_screen.dart`, nếu `remaining < 0` (người vay đã trả nhiều hơn tiền gốc), số tiền hiển thị có dấu `−` và đổi sang màu vàng cảnh báo (`colors.warning`), kèm chú thích "Đã trả vượt số tiền gốc".
4. **Shading ô ngày trên Lịch**:
   - Màu nền ô ngày trên `calendar_screen.dart` được tính chính xác theo công thức quy định: 0 việc (trong suốt), 1–2 việc (alpha 0.15), 3–5 việc (alpha 0.40), 6+ việc (alpha 0.70). Ngày Chủ Nhật được hiển thị số màu đỏ nổi bật.
5. **Đồng bộ màu sắc Chế độ Tối (Dark Mode)**:
   - Toàn bộ card, dialog, dropdown, input fill sử dụng `colors.bgElevated` hoặc `colors.bgSurface` thay vì màu hardcoded, đảm bảo không có chữ xám trên nền xám hoặc viền trắng chói trong chế độ tối.

---

## 4. Các luồng Codex cần kiểm tra lại

1. **Luồng Thu/Chi cơ bản**:
   - Mở form Giao dịch mới từ FAB hoặc nút Giao dịch.
   - Nhập số tiền (kiểm tra tự động thêm dấu phẩy `1,000,000`).
   - Chọn ngày giao dịch (hôm nay hoặc ngày trong quá khứ).
   - Chọn danh mục, thẻ, tài khoản và bấm Lưu.
   - Kiểm tra số tiền xuất hiện đúng trong bảng Thu chi và biểu đồ Tổng quan.
2. **Luồng Công nợ**:
   - Tạo khoản cho vay mới: kiểm tra chọn người liên quan (thử thêm người mới inline khi danh sách trống), nhập số tiền, chọn ngày giao dịch, kiểm tra tài khoản thanh toán là tuỳ chọn.
   - Thu nợ: bấm Thu nợ, nhập số tiền (thử nhập số tiền vượt quá gốc), kiểm tra khoản nợ không bị tự động biến mất/hoàn tất.
   - Hoàn tất thủ công: bấm nút Hoàn tất và xác nhận trong dialog, kiểm tra khoản nợ chuyển sang nhóm "Đã hoàn tất".
3. **Luồng Mua chung / Share bill**:
   - Tạo chi tiêu thuộc danh mục bất kỳ và chọn tag `#Mua chung`.
   - Tạo thu nhập thuộc danh mục "Nhận share bill" và chọn tag tương ứng danh mục chi tiêu.
4. **Luồng Biến động ngân hàng**:
   - Mở tab Biến động, bấm "Bỏ qua" một giao dịch giả lập (kiểm tra Snackbar đếm ngược Hoàn tác trong 3 giây).
   - Bấm "Phân loại", chọn danh mục nhanh từ Top-5 hoặc nút "Khác", chọn tài khoản và xác nhận.
5. **Luồng Đầu tư**:
   - Mở Đầu tư từ Cài đặt, lọc theo kỳ (Tất cả / Năm nay / Tháng này).
   - Thêm giao dịch đầu tư (chi vốn hoặc thu về gốc+lãi), kiểm tra cập nhật chênh lệch lãi/lỗ.
6. **Luồng Lịch**:
   - Mở màn hình Lịch, duyệt qua các tháng, bấm "Hôm nay".
   - Kiểm tra hiển thị các sự kiện Google Calendar và bấm vào ngày để xem chi tiết.
   - Thử mở Cài đặt lịch để bật/tắt hiển thị từng lịch con.
7. **Luồng Ghi chú & Quản lý danh mục**:
   - Tạo ghi chú có ghim và nhắc nhở.
   - Mở các màn Tài khoản, Danh mục, Thẻ, Người liên quan từ Cài đặt.

---

## 5. Những điểm còn hạn chế hoặc chưa hoàn thiện

1. **SVG Vector của Logo**:
   - Bộ nhận diện trong `Quan_ly_PMV_Brand_Kit` hiện là định dạng raster PNG, chưa có vector SVG. Biểu tượng heo tiết kiệm đang hiển thị qua asset raster và Material Icons `savings_outlined`. Nếu sau này có SVG vector gốc, có thể tích hợp thư viện `flutter_svg` để render ở độ phân giải vô hạn.
2. **Giao diện Android Widget Native**:
   - Widget Android `bank_inbox_widget.xml` và `calendar_widget.xml` được viết bằng RemoteViews/XML thuần của Android. Đã cập nhật văn bản tiếng Việt và background bo góc 24dp màu brand. Codex cần kiểm tra hiển thị thực tế trên One UI Launcher của Samsung A54 để xác nhận kích thước font và padding tương thích tốt với lưới widget của Samsung.

---

## 6. Trạng thái kiểm thử

```text
Tests NOT RUN
Analyze NOT RUN
Build NOT RUN
Device verification NOT RUN
```
*(Toàn bộ các bước kiểm thử, phân tích mã tĩnh, build APK và cài đặt nghiệm thu trên Samsung Galaxy A54 sẽ do Codex thực hiện theo đúng phân công công việc).*

---

## Codex review tiếp theo

Đã thực hiện kiểm tra và sửa lỗi sau bàn giao. Xem [codex-ui-review.md](codex-ui-review.md) cho các phát hiện, bản 1.2.0+7, kết quả test/analyze/build và trạng thái còn chờ A54. Các dòng NOT RUN phía trên phản ánh thời điểm Claude bàn giao, không phải trạng thái sau review.
