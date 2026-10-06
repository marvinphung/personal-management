# User App Design Specification & Token System

**Ngày cập nhật:** 05/10/2026  
**Mục tiêu:** Giao diện dịu mắt, phân cấp thông tin rõ ràng, tối ưu hiển thị số tiền và hành động, tương thích đa nền tảng Android / iOS và Widget 2×2 / systemSmall.

---

## 1. Hệ thống Tokens (Semantic Color Tokens)

Dựa trên bảng màu neutral - deep teal, đảm bảo tỷ lệ tương phản WCAG AA (≥ 4.5:1 cho text thường, ≥ 3.0:1 cho text lớn / icon điều hướng).

| Token | Light Hex | Dark Hex | Role & Usage | Contrast Check (Light / Dark) |
|---|---|---|---|---|
| `canvas` | `#F4F5F3` | `#121716` | Scaffold background, nền màn hình chính | — |
| `surface` | `#FCFCFA` | `#1B2321` | Thẻ card, app bar, bottom sheet, navigation bar | — |
| `surfaceRaised` | `#ECEFED` | `#25302C` | Phân vùng phụ, chip, ô tìm kiếm, dialog | — |
| `textPrimary` | `#202A26` | `#E4EAE6` | Tiêu đề, số tiền chính, nội dung đọc chính | 14.2:1 (L) / 11.1:1 (D) |
| `textSecondary` | `#59675F` | `#A8B7AE` | Nhãn phụ, thời gian, mô tả phụ, placeholder | 5.5:1 (L) / 6.7:1 (D) |
| `border` | `#D8E0DA` | `#36443D` | Đường phân cách, viền card tinh tế | 3.2:1 (L) / 3.4:1 (D) |
| `primary` | `#356A59` | `#9BC8B2` | Nút hành động chính (CTA), tab active, accent | 5.4:1 (L) / 7.2:1 (D) |
| `primaryContainer`| `#E0ECE5` | `#29483C` | Tonal pill, highlight nhẹ, badge count | — |
| `income` | `#356D59` | `#9AC6AE` | Số tiền thu nhập (+), chỉ số tiết kiệm tích cực | 5.4:1 (L) / 7.4:1 (D) |
| `expense` | `#A64F49` | `#DCA49C` | Số tiền chi tiêu (−), cảnh báo chi tiêu | 5.3:1 (L) / 6.4:1 (D) |
| `warning` | `#805F28` | `#D4BB86` | Cảnh báo chưa đồng bộ, trạng thái stale | 4.8:1 (L) / 6.1:1 (D) |

### Nguyên tắc thị giác:
- **Dark Mode:** Sử dụng than xanh rất nhẹ (`#121716` / `#1B2321`), không dùng đen thuần `#000000` kết hợp trắng chói `#FFFFFF`.
- **Light Mode:** Dùng off-white (`#F4F5F3` / `#FCFCFA`), loại bỏ viền dày và gradient chói.
- **Biểu đồ & Phân loại:** Giới hạn 4–5 màu muted (Teal `#356A59`, Terra Cotta `#A64F49`, Amber `#805F28`, Slate Blue `#4A6572`, Sage `#5D826E`). Kết hợp biểu tượng và nhãn thay vì chỉ phụ thuộc vào màu sắc.

---

## 2. Typography & Định dạng dữ liệu

- **Font Family:** Font hệ thống chuẩn (Roboto trên Android, San Francisco trên iOS), hỗ trợ tiếng Việt có dấu hoàn chỉnh.
- **Thang kích thước chữ:**
  - `Display / Amount Hero`: 28–32sp, SemiBold, tabular figures (`fontFeatures: [FontFeature.tabularFigures()]`).
  - `Title`: 22–26sp, SemiBold.
  - `Section / Subtitle`: 18–20sp, Medium.
  - `Body`: 15–16sp, Regular.
  - `Secondary / Caption`: 13–14sp, Regular.
  - `Small / Badge`: 11–12sp, Medium.
- **Định dạng tiền tệ:** Luôn có dấu phân cách hàng nghìn, định dạng theo Locale (e.g. `120.000 ₫` hoặc `120,000 VND`), có dấu `+` cho thu nhập và `−` (minus sign `\u2212`) cho chi tiêu.
- **Khả năng tiếp cận:** Hỗ trợ text scaling 1.0, 1.3, 2.0; tự động reflow sang bố cục dọc khi số tiền lớn hoặc cỡ chữ cực đại, không cố định chiều cao cứng gây cắt chữ.

---

## 3. Spacing & Shapes

- **Hệ lưới Spacing:** 4, 8, 12, 16, 24, 32dp.
- **Margin màn hình:** 16dp (mobile tiêu chuẩn) hoặc 20dp.
- **Bán kính góc (Border Radius):**
  - Cards & Dialogs: `16dp`.
  - Input Fields & Dropdowns: `12dp`.
  - Buttons & Chips: `20dp` (Pill / Tonal).
  - Bottom Sheet header: `16dp` bo trên.
- **Vùng bấm tối thiểu (Touch Targets):**
  - Android: Tối thiểu 48×48dp.
  - iOS: Tối thiểu 44×44pt.

---

## 4. Shared Components Specification

1. **`AppPage`**: Bọc cấu trúc scaffold chuẩn, SafeArea tương thích tai thỏ/dynamic island và thanh điều hướng 3 nút / gesture bar, quản lý RefreshIndicator và scroll physics.
2. **`SectionHeader`**: Tiêu đề từng khối (18–20sp), hành động phụ (nút "Xem tất cả", bộ chọn tháng, nút mở filter) bố trí cân đối.
3. **`SummaryCard`**: Thẻ tổng quan full-width. Số tiền chênh lệch ròng (net cashflow) nổi bật ở giữa; Thu nhập và Chi tiêu chia 2 cột cân đối bên dưới với màu semantic; Tỷ lệ tiết kiệm ở chân thẻ.
4. **`MoneyText`**: Hiển thị số tiền với font tabular figures, tự căn lề và đổi màu theo loại giao dịch (income / expense / neutral).
5. **`TransactionRow`**: Dòng giao dịch chuẩn gom theo ngày; Icon danh mục nhỏ; Tên giao dịch & ghi chú rút gọn 1–2 dòng; Số tiền căn phải rõ ràng; Click mở full detail sheet.
6. **`FilterSheet`**: Bottom sheet lọc giao dịch gọn gàng theo Loại, Tài khoản, Danh mục, Khoảng thời gian; Có badge số lượng bộ lọc đang chọn và nút "Xóa lọc".
7. **`AsyncContent`**: Quản lý 4 trạng thái: Loading (Shimmer nhẹ), Error (Nút Thử lại), Empty (Minh họa thân thiện + gợi ý hành động), và Data.
8. **`SyncBanner`**: Hiển thị trạng thái ngoại tuyến hoặc đang đồng bộ ngầm mà không che khuất nội dung đang đọc.
9. **`PendingCard`**: Thẻ biến động ngân hàng gọn gàng: Số tiền to, Ngân hàng + Giờ, Nội dung chuyển khoản; Nút chính "Phân loại" (Tonal), Nút phụ "Bỏ qua".
10. **`SettingsGroup`**: Nhóm cài đặt dạng Card phân vùng rõ ràng (Tài khoản, Giao diện, Dữ liệu, Widget màn hình chính, Thông tin).

---

## 5. Specification Widget 2×2 (Android) & systemSmall (iOS)

- **Nguyên tắc cốt lõi:**
  - Mặc định chỉ hiển thị **số lượng biến động cần phân loại**.
  - **TUYỆT ĐỐI KHÔNG** hiển thị số dư, số tiền giao dịch, số tài khoản, hay nội dung chuyển khoản thô lên Home Screen.
  - Chạm vào toàn bộ widget: Điều hướng đến tab Biến động (`/pending`).
- **Trạng thái Widget:**
  1. *Chưa đăng nhập / Hết hạn:* Biểu tượng khóa + "Đăng nhập để xem".
  2. *Đang cập nhật:* Biểu tượng xoay + "Đang cập nhật...".
  3. *Không có biến động (count = 0):* Biểu tượng hoàn thành + "0" + "Đã xử lý hết".
  4. *Có biến động (count > 0):* Biểu tượng hộp thư + Số lượng lớn (36sp+) + "cần phân loại".
  5. *Ngoại tuyến có cache:* Hiển thị số lượng đã cache kèm chấm cam + "Chưa cập nhật".
- **Bảo mật:**
  - Token widget là scoped token quyền tối thiểu (`/v1/widget-token`), lưu trong Android Keystore / iOS Keychain.
  - Preferences chỉ lưu cache không nhạy cảm (count, last_updated_epoch, is_logged_in).
