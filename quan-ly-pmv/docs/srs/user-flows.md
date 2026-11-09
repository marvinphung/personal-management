# SRS — Các luồng sử dụng

## FL-01 — Đăng nhập và vào app (FR-01, FR-02)

1. Đăng nhập bằng tài khoản Supabase của người dùng.
2. Nếu chưa có lựa chọn ngôn ngữ cho chủ hiện tại, chọn ngôn ngữ rồi tiếp tục.
3. App mở Tổng quan, tải dữ liệu local và tiến hành đồng bộ.
4. Người dùng chuyển giữa bốn tab hoặc mở chức năng từ Cài đặt.

Lỗi đăng nhập/kết nối phải được thông báo; không hiển thị dữ liệu của chủ khác. Đăng xuất không được biến một thông báo của chủ cũ thành đã xử lý cho chủ mới.

## FL-02 — Tạo thu/chi thủ công (FR-04, FR-07)

1. Mở Giao dịch mới.
2. Chọn Chi tiêu hoặc Thu nhập.
3. Nhập số tiền, xem dấu phẩy được thêm ngay.
4. Chọn ngày giao dịch thực tế; có thể là ngày trước đó.
5. Chọn danh mục, tài khoản và tag phù hợp; ghi chú riêng tùy chọn.
6. Lưu. App lưu local, cập nhật danh sách/tổng/biểu đồ và đưa vào hàng đợi đồng bộ.

Số tiền không hợp lệ hoặc thiếu trường bắt buộc: giữ form và dữ liệu đã nhập, chỉ ra lỗi. Nếu chọn Công nợ, thực hiện phần đặc thù ở FL-05/06 thay vì lưu như một khoản thường không liên kết.

## FL-03 — Tìm, mở và sửa giao dịch (FR-05)

1. Vào Thu chi hoặc tìm kiếm toàn cục.
2. Chọn tháng/tìm/lọc để thấy giao dịch.
3. Mở chi tiết và chọn Sửa đối với giao dịch được sửa trực tiếp.
4. Cập nhật trường cho phép và lưu; thống kê phản ánh thay đổi.
5. Với dòng tiền công nợ, mở khoản nợ liên kết để quản lý nhất quán.

Giao dịch có nguồn ngân hàng: số tiền, hướng/loại tiền, thời gian và mô tả nguồn đã xác nhận chỉ đọc; chỉ sửa phần phân loại/ghi chú được phép.

## FL-04 — Phân loại hoặc bỏ qua biến động (FR-09–11)

1. Mở Biến động trực tiếp hoặc từ widget.
2. Xem thông tin nguồn; chọn Phân loại.
3. Chọn một trong năm danh mục gợi ý hoặc Khác để mở toàn bộ danh mục đúng hướng tiền.
4. Chọn tag/ghi chú và tài khoản phù hợp; nếu Công nợ, chọn hành động và người/khoản liên quan.
5. Xác nhận: tạo bản ghi sổ và liên kết cần thiết đúng một lần, rồi hoàn tất xử lý thông báo.

Nhánh Bỏ qua:

1. Bấm Bỏ qua; mục ẩn ngay và hiện Hoàn tác trong 3 giây.
2. Bấm Hoàn tác còn hạn: mục trở lại; không tạo giao dịch.
3. Hết hạn: hoàn tất bỏ qua với native. Nếu lỗi, giữ trạng thái có thể retry.
4. Bỏ qua mục tiếp theo sẽ hoàn tất slot trước trước khi bắt đầu slot mới; không có hai slot song song.

Không sử dụng thông báo thật làm dữ liệu thử trong quá trình nghiệm thu.

## FL-05 — Tạo Cho vay/Vay nợ và thêm người (FR-08, FR-12)

1. Vào Cài đặt → Công nợ → Tạo khoản nợ, chọn Cho vay hoặc Vay nợ.
2. Chọn người liên quan. Nếu chưa có, chọn Thêm người mới, lưu rồi chọn ngay người vừa thêm.
3. Nhập số tiền gốc. Dữ liệu tiền/ngày đã nhập không bị xóa khi thêm người.
4. Chọn Ngày giao dịch, bao gồm ngày trong quá khứ.
5. Tài khoản thanh toán có thể để trống; hạn trả riêng/tùy chọn; ghi chú tùy chọn.
6. Lưu một lần: tạo khoản nợ và giao dịch chi (Cho vay) hoặc thu (Vay nợ) liên kết, trong cùng lần lưu nguyên tử.

Điểm vào khác: từ form Thu chi hoặc phân loại ngân hàng, chọn Công nợ và hành động Cho vay/Vay nợ. Hành động Công nợ không được thay bằng tag Mua chung.

## FL-06 — Thu nợ/Trả nợ và hoàn tất (FR-12, FR-13)

1. Mở chi tiết khoản công nợ và chọn Thu nợ hoặc Trả nợ theo chiều khoản đó.
2. Nhập số tiền và ngày thu/trả thực tế; tài khoản thanh toán tùy chọn.
3. Lưu lần thanh toán và giao dịch liên kết; dư nợ cập nhật theo lịch sử.
4. Nếu nhập từ Thu chi/Biến động, phải dùng Chọn danh sách công nợ để chỉ ra đúng khoản đang theo dõi.
5. Tiền có thể lớn hơn dư còn lại; số dư âm vẫn được lưu và hiển thị.
6. Khi muốn kết thúc, bấm Hoàn tất và xác nhận. Khoản chuyển sang nhóm Đã hoàn tất, giữ nguyên gốc/lịch sử.

Không tự hoàn tất khi dư bằng 0; không tự thêm khoản chi/thu để ép dư về 0. Khoản hoàn tất không nằm trong bộ chọn thanh toán mới.

## FL-07 — Sửa khoản công nợ (FR-13)

1. Mở khoản trong Công nợ → Chỉnh sửa.
2. Chỉnh người, số tiền gốc, ngày giao dịch, tài khoản, hạn trả và ghi chú theo trường được phép.
3. Lưu nguyên tử cả khoản nợ và giao dịch gốc liên kết.
4. Giữ các lần thu/trả, ID liên kết và trạng thái hoàn tất; tính lại dư theo gốc mới.

Nguồn ngân hàng giữ các trường nguồn chỉ đọc. Không đổi chiều khoản nợ đã có thanh toán vì sẽ làm sai ý nghĩa lịch sử.

## FL-08 — Ghi và xem Đầu tư (FR-14)

1. Mở Cài đặt → Đầu tư, chọn Thêm giao dịch; hoặc vào form Thu chi và chọn Đầu tư.
2. Chọn Chi tiêu khi bỏ vốn, Thu nhập khi nhận tiền về.
3. Ghi số tiền, ngày và tag loại đầu tư; số thu nhận về là toàn bộ gốc+lãi.
4. Lưu. Dòng tiền tham gia cả sổ thu/chi chung và thống kê đầu tư.
5. Trong Đầu tư, lọc kỳ/tag; xem vốn, tiền về và chênh lệch; mở giao dịch để sửa trường cho phép.

Chênh lệch trong một kỳ chỉ mô tả dòng tiền kỳ đó, không mặc định là lợi nhuận đã thực hiện của toàn bộ danh mục.

## FL-09 — Mua chung và Nhận share bill (FR-15)

1. Khi thanh toán cho nhóm, giữ danh mục Chi tiêu đúng hoạt động và chọn thêm Mua chung.
2. Khi nhận lại tiền chia bill, ghi Thu nhập → Nhận share bill.
3. Chọn tag tên danh mục chi tương ứng, ví dụ Ăn uống hoặc Nhà & hóa đơn.
4. Lưu từng dòng tiền thực tế, không xóa/bù trừ hai giao dịch; báo cáo tính phần chi cá nhân của bill và không cộng nhận lại vào thu.

### Theo dõi bill trả hộ và nhận lại tiền

1. Tạo Chi tiêu thủ công ngoài Công nợ, giữ danh mục hoạt động; bật **Chia bill với nhóm**.
2. Nhập **Tổng số người (gồm bạn)** và **Số người đã trả** (mặc định 1 là bạn), điền tiền/ngày/tài khoản rồi Lưu. Bill và giao dịch chi được lưu cùng nhau.
3. Mở **Cài đặt → Share Bill** để xem Đang chờ nhận/Đã hoàn tất theo tiền tệ đang xem; bấm bill để xem tiến độ và lịch sử.
4. Tạo Thu nhập hoặc phân loại biến động tiền vào, bật thanh gạt **Nhận Share Bill**; chọn bill chưa hoàn tất cùng tiền tệ. Số người của lần nhận mặc định 1, bấm **−/+** để thay đổi (ví dụ một người trả hộ hai người thì chọn 2). Nhập số tiền/ngày thực nhận cho giao dịch thủ công; thông báo ngân hàng giữ trường nguồn. Bật theo dõi thì bắt buộc chọn bill; tắt theo dõi vẫn ghi thu thông thường.
5. Mặc định đã trả 1 là bạn; mỗi lần nhận cộng đúng số người đã chọn vào tiến độ; đạt số người dự kiến thì tự chuyển Đã hoàn tất. Có thể bấm **Hoàn tất** sớm trong chi tiết mà không tạo thêm dòng tiền.
6. Trong lịch sử bill, xóa lần nhận sẽ xóa mềm cả giao dịch thu liên kết, trừ số người của lần nhận và đưa bill tự hoàn tất về đang chờ nếu chưa đủ người; bill Hoàn tất thủ công giữ nguyên.
7. Bấm **Sửa Share Bill** trong chi tiết để chỉnh giao dịch chi và số người dự kiến; bấm một lần nhận trong lịch sử để chỉnh tiền/ngày/số người hoặc bill liên kết. Mở form phải khôi phục liên kết và giữ các lần nhận đã có khi Lưu.

Theo dõi bill không bắt buộc dùng tag Mua chung và không được tự tạo chỉ vì có tag này. Liên kết nhận tiền dùng được cả nhập thủ công và phân loại ngân hàng, luôn giữ nguồn ngân hàng read-only và retry không tạo thêm lần nhận.

Trong Công nợ chi tiêu, Mua chung chỉ là marker bổ sung; vẫn phải chọn Cho vay/Trả nợ và người/khoản liên quan.

## FL-10 — Ghi chú (FR-16)

Mở Cài đặt → Ghi chú → tạo mới/mở ghi chú → nhập tiêu đề/nội dung → chọn ghim, mốc nhắc nhở, liên kết nếu cần → Lưu. Tìm kiếm và danh sách phản ánh nội dung/trạng thái; ghim được ưu tiên hiển thị.

## FL-11 — Xem lịch và widget (FR-17, FR-18)

1. Mở Cài đặt → Lịch; cấp quyền đọc khi Android yêu cầu.
2. Vào cài đặt lịch và chọn các lịch con của tài khoản Google cá nhân đã cấu hình.
3. Xem tháng, chuyển tháng/Hôm nay; bấm ngày để thấy sự kiện và giờ.
4. Trên widget 4×2, chọn ngày để đổi phần sự kiện bên phải; bấm phần mở app để vào đúng ngày/tháng.
5. Lựa chọn lịch trong app và widget phải thống nhất; bỏ chọn hết nghĩa là không chọn lịch nào.

Không có quyền: hiện giải thích và lối xin quyền, không crash. Dữ liệu Google chưa sync vào thiết bị thì không được giả là app đã tải lịch mới nhất.

## FL-12 — Offline và retry (FR-19, FR-20)

1. Mất mạng: vẫn đọc dữ liệu local và tạo/sửa các bản ghi được hỗ trợ.
2. Lưu thay đổi cùng outbox; hiển thị trạng thái chờ đồng bộ.
3. Đóng/mở app: thay đổi chưa sync vẫn còn.
4. Có mạng: đẩy/retry và đối soát dữ liệu theo chủ; không nhân đôi bản ghi.
5. Nếu lỗi/xung đột, thông báo trạng thái thật và cho retry; không nói đã sync khi chưa xác nhận.

## FL-13 — Debug bộ đọc ngân hàng (FR-09, FR-19)

1. Khi không nhận được biến động, mở Cài đặt → Ngân hàng → Debug.
2. Chờ kiểm tra; nút không chạy lặp trong lúc đang xử lý.
3. Nếu thiếu quyền/đang tắt thu thập, app chỉ rõ thiết lập cần bật; không tự bật thay người dùng.
4. Nếu mất kết nối, app thử khôi phục và xác minh callback. Hiển thị bộ đọc đang kết nối/đã kết nối lại hoặc chưa khôi phục được.
5. Khi kết nối đã có, thử thông báo giao dịch mới và xem Biến động. Debug giữ nguyên sổ giao dịch, lựa chọn ngân hàng và thông báo chờ.
