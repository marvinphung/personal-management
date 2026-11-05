# Tài liệu đặc tả Quản lý PMV

Bộ SRS hiện hành của app cá nhân **Quản lý PMV**, dùng trên Samsung Galaxy A54. Cập nhật theo yêu cầu đã chốt đến ngày 05/11/2026. Các file dưới đây mô tả sản phẩm cần làm và tiêu chí chấp nhận; không phải kế hoạch triển khai hoặc báo cáo chạy test.

| Tài liệu | Nội dung |
|---|---|
| [Tổng quan và phạm vi](srs/overview.md) | Người dùng, nền tảng, mục tiêu và giới hạn sản phẩm |
| [Tính năng](srs/features.md) | Yêu cầu chức năng có mã định danh |
| [User story](srs/user-stories.md) | Nhu cầu người dùng và kết quả mong đợi |
| [Luồng sử dụng](srs/user-flows.md) | Các bước sử dụng và tình huống ngoại lệ |
| [Quy tắc nghiệp vụ](srs/business-rules.md) | Tiền, tổng thu/chi, công nợ, tag, ngân hàng và lịch |
| [Mô hình dữ liệu](srs/data-model.md) | Các thực thể, quan hệ và ràng buộc dữ liệu |
| [Danh mục và tag](srs/catalog.md) | Bộ danh mục/tag mặc định đã chốt |
| [Phi chức năng và nghiệm thu](srs/acceptance.md) | Khả dụng, chính xác, riêng tư, offline và tiêu chí chấp nhận |

## Cách duy trì

- Đọc [AGENTS.md](../AGENTS.md) trước khi sửa code hoặc tài liệu.
- Khi yêu cầu thay đổi, sửa phần đặc tả liên quan và các liên kết/truy vết; không để yêu cầu cũ trái với yêu cầu mới.
- Không ghi plan, task triển khai, prompt, handoff, log hoặc kết quả test/build vào `docs/`.
- Plan mới ở `../plans/`, bắt buộc có timestamp tạo thực tế trong tên file và metadata theo `AGENTS.md`.
- Tài liệu kỹ thuật/bàn giao cũ được giữ ngoài SRS tại [reference/engineering/](../reference/engineering/README.md). Không dùng tài liệu lưu trữ làm đặc tả hiện hành.
