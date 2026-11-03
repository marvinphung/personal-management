# Quản lý PMV — Brand & App Icon Kit

Bộ nhận diện được tách và chuyển đổi **trực tiếp từ logo con heo tiết kiệm mà bạn đã chọn**. Không thay đổi logo gốc; các biểu tượng app chỉ bổ sung nền và khoảng đệm để hiển thị rõ hơn.

## Cấu trúc

- `00-original/logo-selected-original.png`: ảnh gốc người dùng chọn, độ phân giải 1448×1086, nền trong suốt.
- `01-brand/logo-horizontal-transparent.png`: logo đầy đủ, PNG nền trong suốt; dùng ở thanh điều hướng, trang giới thiệu.
- `01-brand/logo-horizontal-on-white.png`: logo đầy đủ trên nền trắng.
- `01-brand/logo-horizontal-on-dark.png`: biến thể cho nền tối (chữ xanh đậm được làm sáng hơn).
- `01-brand/piggy-mark-transparent-{512,1024}.png`: biểu tượng heo tách riêng, nền trong suốt.
- `02-app-icons/app-icon-1024.png`: **icon ứng dụng chính**, vuông, không có alpha; nên dùng làm nguồn để build.
- `02-app-icons/app-icon-{16..512}.png`: những phiên bản giảm kích thước của icon chính.
- `02-app-icons/app-icon-dark-1024.png`: phiên bản nền tối.
- `02-app-icons/app-icon-maskable-{192,512}.png`: hình ảnh có khoảng đệm an toàn dành cho icon PWA dạng maskable.
- `03-android/mipmap-*/ic_launcher.png` và `ic_launcher_round.png`: icon Android legacy ở các mật độ màn hình.
- `03-android/adaptive-icon-foreground-432.png`: lớp trước trong suốt, vật thể nằm vùng an toàn adaptive icon.
- `03-android/adaptive-icon-background-432.png`: nền icon Android; nếu dùng drawable XML thì xuất/copy các layer tương ứng.
- `03-android/adaptive-icon-monochrome-432.png`: mask đơn sắc để Android dùng cho themed icon.
- `04-ios/AppIcon.appiconset/`: có `Contents.json` cùng các kích thước iPhone, iPad và App Store, PNG không trong suốt.
- `05-web/`: favicon, icon PWA, Apple touch icon và mẫu manifest.
- `06-splash/`: màn hình khởi động sáng/tối mẫu; các framework có thể dùng thiết kế splash riêng.
- `08-previews/asset-preview.jpg`: ảnh xem nhanh bộ nhận diện.

## Tích hợp

**Web / Vite / React:** Copy `05-web/` vào `public/` (chọn đổi tên các file nếu project đã có icon), cập nhật `index.html` các thẻ favicon, apple-touch-icon, manifest. Copy logo từ `01-brand/` vào thư mục assets và import đúng đường dẫn.

**Android thuần:** thay launcher legacy trong `res/mipmap-*`; adaptive icon đặt các lớp vào `res/drawable-nodpi/` hoặc resource phù hợp và tham chiếu qua `mipmap-anydpi-v26/ic_launcher.xml`. `ic_launcher.xml.example` chỉ mang tính minh họa, cần đổi tên resource và cấu hình theo project.

**Flutter:** dùng `app-icon-1024.png` với flutter_launcher_icons, hoặc dùng adaptive foreground/background nếu muốn. Cần build lại để Android/iOS refresh asset.

**React Native / Expo:** dùng `app-icon-1024.png` làm icon, và các layer trong `03-android/` để thiết lập `android.adaptiveIcon`; bản dùng maskable cho PWA.

**iOS/Xcode:** copy `04-ios/AppIcon.appiconset` vào `Assets.xcassets` hoặc thay AppIcon hiện tại. Hệ điều hành sẽ bo góc khi hiển thị: không bo góc trước ảnh iOS.

## Quy định sử dụng

- Tên đầy đủ trong giao diện: **Quản lý PMV** (giữ dấu tiếng Việt).
- Icon launcher: chỉ biểu tượng, **không nhét chữ** vào icon nhỏ.
- Biểu tượng nền trong suốt: `piggy-mark-transparent-1024.png`.
- Màu sắc tham khảo: deep teal `#005E5D`, mint background `#EFFCF9`, navy `#071F31`, lime green `#42C245`, gold `#ECB02E`.
- PNG trong bộ là ảnh raster, không phải SVG vector gốc. Nếu cần SVG có thể dựng lại thủ công để đạt kết quả sắc nét chính xác.
- Không tự ý thay đổi hình con heo, ký hiệu ₫, biểu đồ, hay kiểu chữ trong logo gốc; chỉ chỉnh kích thước/cách trình bày theo không gian.
