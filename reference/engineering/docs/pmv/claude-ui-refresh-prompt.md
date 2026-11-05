# Prompt giao Claude Code: làm mới giao diện Quản lý PMV

Bạn là kỹ sư Flutter có chuyên môn thiết kế sản phẩm Android. Hãy trực tiếp cải thiện giao diện app Quản lý PMV để đẹp, đồng bộ, dễ đọc và thao tác nhanh trên Samsung A54. Đây là app cá nhân, một người dùng, chỉ dùng trên chiếc A54; dữ liệu cloud là Supabase, có SQLite/outbox để hoạt động offline.

## Bắt đầu

- Dùng branch `feature/quan-ly-pmv` làm nền, tạo branch `feature/pmv-ui-refresh`; không sửa/merge vào main. Giữ mọi thay đổi có sẵn, không reset worktree.
- Đọc AGENTS.md nếu có; nếu repo có `.codegraph/` thì dùng CodeGraph trước để tìm hiểu code.
- Đọc `docs/pmv/data-contract.md`, `docs/pmv/codex-fix-report.md`, `docs/pmv/debt-dates-verification.md` và `docs/pmv/shared-bills-verification.md`. Lưu ý tài liệu có lịch sử thay đổi: quy tắc hiện tại luôn tính mọi thu/chi, không còn tùy chọn loại trừ.
- Kiểm tra code và màn hình hiện tại trước khi sửa. Flutter Android ở `android/`; UI và nghiệp vụ dùng chung ở `linux/packages/finance_core/`. Brand kit nằm trong `Quan_ly_PMV_Brand_Kit/`.
- Nếu có skill phù hợp cho thiết kế mobile/frontend thì áp dụng. Chỉ hỏi khi thiếu quyết định quan trọng; hỏi từng vấn đề một. Tự xử lý lựa chọn trình bày thông thường và triển khai đến khi chạy được.

## Mục tiêu thiết kế

Thiết kế như một app Android tài chính cá nhân hoàn chỉnh: gọn, sáng rõ, có cá tính từ brand kit, nhất quán giữa màn hình chính và các form. Dùng Material 3 phù hợp Android/One UI, hoàn thiện cả sáng và tối. Giữ logo/nhận diện PMV; không tự đổi tên app hay logo.

Cải thiện typography, khoảng cách, bảng màu, tương phản, icon, phân cấp số tiền, biểu đồ, trạng thái trống/loading/lỗi và phản hồi khi bấm. Đặt khả năng đọc số tiền và thao tác một tay lên trước trang trí. Số tiền dùng chữ số tabular và phân cách hàng nghìn; vùng chạm tối thiểu 48dp. Tránh lạm dụng gradient, hiệu ứng kính, bóng đổ nặng, card lồng card và animation làm chậm thao tác. Không tạo ảnh mockup rồi dừng: phải sửa UI Flutter thật.

## Phạm vi

- Shell bốn tab Tổng quan / Thu chi / Biến động / Cài đặt: thanh điều hướng chỉ hiện icon, vẫn có tooltip và accessibility label.
- Tổng quan: thu nhập, chi tiêu, chênh lệch, biểu đồ và các phần thống kê có thứ bậc rõ; danh sách giao dịch dễ quét.
- Thu chi, chi tiết giao dịch, form tạo/sửa: nhóm trường hợp lý, bàn phím không che nút lưu, không tràn/che nhãn, chọn danh mục/tag dễ thao tác.
- Biến động: thông tin ngân hàng, phân loại, chọn người/khoản nợ và Undo 3 giây rõ ràng.
- Cài đặt, Công nợ, Đầu tư, Ghi chú, các danh mục/người liên quan: dùng chung hệ thống giao diện, có lối tạo/sửa rõ ràng.
- Lịch: tháng mặc định, tuần bắt đầu thứ Hai, không ngày âm, tham khảo sự rõ ràng của Samsung Calendar; ngày có nhiều việc có màu đậm hơn. Giữ widget Lịch 4×2 và Biến động 2×2, có thể chỉnh phần trình bày cho đồng bộ.

## Hành vi bắt buộc giữ

- Mọi thu/chi, kể cả Công nợ và Đầu tư, luôn được tính vào tổng và biểu đồ. Không khôi phục công tắc “Không tính vào tổng thu/chi”.
- Mọi ô nhập tiền tự hiển thị dấu phẩy: 1000000 → 1,000,000; 4321 → 4,321. Giữ số nguyên chính xác và khả năng sửa/xóa/dán.
- Công nợ hai chiều: Chi tiêu có Cho vay/Trả nợ; Thu nhập có Thu nợ/Vay nợ. Thu/trả chọn khoản nợ liên quan, cập nhật lịch sử; cho phép trả vượt gốc; chỉ hoàn tất khi người dùng bấm Hoàn tất.
- Tạo/sửa Công nợ chọn Ngày giao dịch được, ghi lùi ngày được; Hạn trả là trường riêng và tùy chọn. Thu/trả nợ cũng có ngày. Tài khoản thanh toán của Công nợ là tùy chọn. Giữ đồng bộ ngày/số tiền giữa công nợ và giao dịch liên kết.
- Người liên quan phải luôn chọn/thêm được, kể cả danh sách trống; thêm người không làm mất số tiền đang nhập.
- Mỗi danh mục Chi tiêu có tag Mua chung. Thu nhập có Nhận share bill, tag là tên các danh mục Chi tiêu. Hiển thị tên tiếng Việt từ display_name, không lộ slug nội bộ. Tag Mua chung bổ sung cho Công nợ, không thay hành động công nợ bắt buộc.
- Đầu tư và Công nợ mở từ Cài đặt; giữ khả năng mở lại để chỉnh sửa/cập nhật. Đầu tư ghi tiền nhận về gồm cả gốc+lãi.
- Lịch chỉ đọc dữ liệu tài khoản Google đã cấu hình; không thêm quyền ghi. Giữ lựa chọn lịch và liên kết app/widget.
- Thông tin gốc từ ngân hàng đã xác nhận vẫn read-only. Không xác nhận/bỏ qua thông báo thật để thử giao diện.

## Giới hạn và nghiệm thu

Chỉ thay đổi giao diện và tương tác trình bày cần thiết. Giữ API, schema, cách tính tiền, sync/offline, quyền truy cập và dữ liệu hiện tại. Không reset DB, không xóa dữ liệu người dùng, không thêm backend/đăng nhập mới hay tính năng trả góp/bank balance đã bỏ. Không đưa .env, signing key, ảnh/log tài chính cá nhân vào Git.

Trước tiên báo ngắn các vấn đề UI thấy được và hướng thiết kế, sau đó triển khai theo từng nhóm component/màn hình. Ưu tiên sửa theme/component dùng chung, rồi các màn hình/form. Dùng dữ liệu giả trong test/preview; không thay đổi giao dịch thật để chụp ảnh đẹp.

Chạy test/analyze tại `linux/packages/finance_core`, bổ sung test khi thay đổi tương tác có rủi ro và build Android. Nếu A54 đã được người dùng cho phép ADB và máy đang mở khóa, chụp/kiểm tra màn hình thực tế ở khổ dọc, bàn phím mở và cả hai theme; không yêu cầu mã PIN. Dùng bộ ký hiện có nếu cần cài cập nhật, tuyệt đối không tạo signing key thay thế. Nếu thiếu kết nối/thiết bị, báo đúng phần chưa kiểm tra, không nhận là đã nghiệm thu.

Kết thúc bằng danh sách thay đổi, ảnh trước/sau lưu local, kết quả kiểm thử/build và phần còn hạn chế. Cập nhật docs, không tự push/merge khi chưa được yêu cầu. Codex sẽ review lại kết quả.
