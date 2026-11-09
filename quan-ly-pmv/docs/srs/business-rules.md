# SRS — Quy tắc nghiệp vụ

## Tiền và tổng hợp

- **BR-01 — Tiền chính xác:** lưu/tính tiền bằng số nguyên đơn vị nhỏ nhất của tiền tệ; không dùng số thực cho số tiền gốc. Tỷ lệ/đồ thị có thể dùng số thực ở lớp trình bày. Giới hạn giá trị theo bộ kiểm tra tiền hiện có, tối đa 9,000,000,000,000,000 đơn vị nhỏ nhất.
- **BR-02 — Nhập tiền:** `1000000` hiển thị `1,000,000`, `4321` hiển thị `4,321`; dấu phẩy không đổi giá trị khi lưu. Sửa/xóa/dán và vị trí con trỏ phải sử dụng được.
- **BR-03 — Loại giao dịch:** thu nhập/chi tiêu có số tiền dương và hướng tiền riêng; chuyển khoản có hai tài khoản khác nhau, cùng tiền tệ.
- **BR-04 — Tổng thu/chi:** cộng mọi dòng thu/chi hợp lệ, chưa xóa, trong kỳ và đúng tiền tệ; Công nợ và Đầu tư tính toàn bộ. Với Share Bill có theo dõi, chỉ cộng phần chi cá nhân bằng tiền giao dịch chi gốc trừ tổng số tiền thực nhận chưa xóa liên kết đúng bill; giao dịch thu liên kết bill hoặc thuộc danh mục Nhận share bill không cộng tổng thu. Không có công tắc loại trừ. Cờ loại trừ từ dữ liệu cũ không được làm giảm tổng.
- **BR-05 — Chuyển nội bộ:** ảnh hưởng hai tài khoản nhưng không cộng vào tổng thu nhập hoặc chi tiêu. Không tự ghép/chốt cặp thông báo ngân hàng để quyết định thay người dùng.
- **BR-06 — Kỳ và dấu:** tổng/biểu đồ theo ngày giao dịch tại múi giờ thiết bị, không phải ngày tạo bản ghi. Chênh lệch = thu − chi; giá trị âm phải có dấu âm, không chỉ đổi màu. Không cộng gộp các tiền tệ khác nhau như cùng đơn vị.
- **BR-07 — Lịch sử cũ:** bản ghi đã xóa không tham gia tổng. Dữ liệu trả góp legacy còn được đọc phải giữ bộ lọc scheduled của hệ thống; không cung cấp tính năng tạo trả góp mới.

## Công nợ

| Hành động | Danh mục | Loại giao dịch | Khoản liên quan |
|---|---|---|---|
| Cho vay | Công nợ bên Chi tiêu | Chi tiêu | Tạo khoản người khác nợ tôi |
| Vay nợ | Công nợ bên Thu nhập | Thu nhập | Tạo khoản tôi nợ người khác |
| Thu nợ | Công nợ bên Thu nhập | Thu nhập | Chọn khoản Cho vay hiện có |
| Trả nợ | Công nợ bên Chi tiêu | Chi tiêu | Chọn khoản Vay nợ hiện có |

- **BR-08 — Đúng một hành động:** chọn hành động Công nợ phù hợp hướng thu/chi; tạo mới cần người liên quan, thanh toán cần khoản liên quan. Mua chung không thay thế hành động này.
- **BR-09 — Lưu nguyên tử:** một thao tác tạo gốc/thu/trả phải lưu cùng giao dịch, khoản/lần thanh toán và liên kết tag cần thiết. Không được có khoản nợ mà mất dòng tiền do một nửa lần lưu thất bại.
- **BR-10 — Ngày và tài khoản:** ngày giao dịch cho chọn quá khứ; tài khoản thanh toán là tùy chọn. Hạn trả khác ngày giao dịch và có thể để trống. Ngày tạo bản ghi giữ thời điểm thực tế nhập.
- **BR-11 — Dư nợ:** còn lại = gốc − tổng các lần thu/trả chưa xóa. Cho phép trả vượt gốc, không clamp về 0, hiển thị dư âm rõ ràng.
- **BR-12 — Hoàn tất thủ công:** chỉ nút Hoàn tất làm khoản chuyển vào nhóm hoàn tất; không tự hoàn tất vì dư bằng/nhỏ hơn 0. Không tạo giao dịch cân bằng. Giữ gốc, các lần thanh toán và lịch sử.
- **BR-13 — Sửa:** sửa gốc/ngày phải sửa nhất quán giao dịch gốc liên kết; giữ ID, thanh toán và trạng thái hoàn tất. Không đổi chiều khoản đã có thanh toán. Không sửa trường nguồn ngân hàng để vượt cơ chế read-only.
- **BR-14 — Bộ chọn thanh toán:** chỉ đưa các khoản còn phù hợp trạng thái/chiều để thu/trả; khoản hoàn tất/hủy không phải khoản nhận thanh toán mới.

## Đầu tư và share bill

- **BR-15 — Đầu tư:** vốn bỏ vào = tổng chi thuộc Đầu tư; tiền nhận về = tổng thu Đầu tư gồm gốc+lãi; chênh lệch = nhận về − vốn. Bộ lọc kỳ/tag áp dụng nhất quán cả hai chiều dù ID danh mục/tag thu và chi khác nhau. Khoản bị lọc khỏi báo cáo riêng không bị xóa khỏi sổ.
- **BR-16 — Báo cáo chung:** dòng tiền Đầu tư vẫn cộng vào tổng thu/chi đúng một lần. Không đặt một module Đầu tư riêng trên Tổng quan; truy cập từ Cài đặt.
- **BR-17 — Mua chung/share bill:** mỗi danh mục chi có tag Mua chung riêng gắn đúng danh mục. Danh mục thu Nhận share bill có tag là tên các danh mục chi, kể cả Công nợ/Đầu tư. Sổ giữ nguyên hai giao dịch trả hộ/nhận lại và không tự sinh Công nợ; thống kê Share Bill áp dụng BR-04. Tag Mua chung đơn thuần không có bill/số người vẫn là giao dịch chi thông thường.
- **BR-28 — Bill trả hộ:** theo dõi bill là tùy chọn khác với tag Mua chung. Trong giao dịch chi thủ công hoặc phân loại thông báo tiền ra ngoài Công nợ, bật Chia bill với nhóm và nhập tổng số người (gồm bạn, số nguyên dương); số người đã trả mặc định 1 là bạn và chỉnh được khi tạo/sửa. Lưu bill và giao dịch chi cùng một thao tác nguyên tử. Chỉ thêm tag Mua chung không tự tạo bill.
- **BR-29 — Nhận tiền và tiến độ:** giao dịch Thu nhập thủ công hoặc biến động tiền vào có thanh gạt Nhận Share Bill; bật lên chọn danh mục Nhận share bill và hiện bill chưa hoàn tất cùng chủ, cùng tiền tệ ghi sổ. Mỗi lần nhận liên kết với một giao dịch thu và có số người được trả hộ, mặc định 1; nút −/+ đổi số nguyên dương. Tiến độ bằng số người đã trả ban đầu (gồm bạn) cộng tổng số người của các lần nhận chưa xóa, không phải số giao dịch hay xác minh danh tính. Đạt số người dự kiến thì tự hoàn tất. Khác Công nợ, Share Bill có tự hoàn tất theo tiến độ.
- **BR-30 — Lịch sử và hoàn tất:** cho hoàn tất thủ công trước khi đủ lượt, không sinh giao dịch cân bằng. Xóa một lần nhận phải xóa mềm cả dòng thu liên kết, trừ đúng số người của lần nhận và mở lại bill tự hoàn tất nếu chưa đủ người; bill đã Hoàn tất thủ công giữ trạng thái thủ công. Cho sửa bill qua chi tiết và sửa lần nhận qua lịch sử: khôi phục số người, bill liên kết, ngày/tiền/ghi chú và giữ lịch sử/ID. Khi sửa số người dự kiến hoặc số người của lần nhận phải tính lại tiến độ; sửa/retry cùng giao dịch không tăng trùng. Bill đã có lần nhận không được đổi tiền tệ. Sửa giao dịch nguồn ngân hàng vẫn giữ trường nguồn read-only.
- **BR-31 — Số tiền và đồng bộ bill:** các số tiền thực nhận phải lấy từ những lần nhận chưa xóa; không giả định mọi lượt trả cùng số tiền. Bill, payment, giao dịch và outbox lưu nguyên tử, retry không trùng. Hai bảng bill/payment phải có trên cloud để đồng bộ toàn bộ thực thể không bị lỗi. Tổng thu/chi theo BR-04: phần của bạn vào chi, nhận lại không vào thu; không xóa/bù trừ giao dịch gốc hoặc sinh Công nợ.
- **BR-18 — Nhãn và ID:** tag có ID/slug ổn định, tên lưu được chuẩn hóa; `display_name` nếu có là nhãn hiển thị, nếu không dùng bảng nhãn tiếng Việt hiện có. Không hiện chuỗi nội bộ cho người dùng hoặc đổi ID khi đổi cách trình bày. Các tag nhìn cùng tên nhưng khác danh mục phải liên kết đúng bản ghi.

## Ngân hàng và Undo

- **BR-19 — Tiếp nhận có chủ đích:** chỉ nhận thông báo mới hợp lệ sau khi bật thu thập từ nguồn được hỗ trợ; không hứa khôi phục toàn bộ lịch sử thông báo cũ. Quyền Android, bật capture và dịch vụ kết nối là các trạng thái khác nhau.
- **BR-20 — Read-only:** nguồn đã xác nhận gồm hướng/loại tiền, số tiền, tiền tệ, thời gian, ngân hàng và mô tả gốc. Phần phân loại/ghi chú cho phép sửa không được thay các trường nguồn. Không tải nguyên văn notification thô lên cloud hoặc lấy số dư ngân hàng làm giao diện báo cáo.
- **BR-21 — Retry:** xác nhận hoặc retry một draft không tạo thêm giao dịch/nợ/lần thanh toán trùng. Lưu provenance chuẩn hóa cùng giao dịch; chỉ hoàn tất đóng draft sau khi phần lưu liên quan thành công.
- **BR-22 — Undo:** có một slot bỏ qua bền vững với owner, draft và deadline 3 giây. Restart không gia hạn. Slot hết hạn chỉ xóa sau khi native hoàn tất; lỗi còn retry được. Hoàn tác khi còn hạn trả mục về danh sách. Đổi chủ/đăng xuất không được finalize nhầm draft của chủ cũ.
- **BR-23 — Badge/widget:** số chờ phải thống nhất với danh sách, trừ mục đang ẩn trong slot Undo, kể cả lúc native cần retry; không dùng số dư/tiền làm nội dung widget Biến động.

## Lịch và quyền riêng tư

- **BR-24 — Nguồn lịch:** đọc tài khoản Google cá nhân đã cấu hình qua Calendar Provider; dùng các instance sự kiện để giữ lặp lại/cả ngày/nhiều ngày. Không xin quyền ghi lịch và không sửa Google Calendar.
- **BR-25 — Hiển thị:** mặc định tháng, thứ Hai đầu tuần, không ngày âm; màu ngày đậm dần theo lượng sự kiện. Chữ phải tương phản cả trên nền ngày dày việc và chip màu sáng. Ngày hiện tại vẫn được đánh dấu.
- **BR-26 — Lựa chọn dùng chung:** app và widget dùng cùng bộ lịch con đã chọn; chọn rỗng vẫn là rỗng, không tự bật lại tất cả. Chọn ngày trên widget cập nhật phần sự kiện; mở app đến đúng ngày được chọn và không xử lý lặp deep link cũ.
- **BR-27 — Chủ dữ liệu:** mọi bản ghi, pending/outbox và truy cập cloud thuộc đúng người dùng. Không dùng dữ liệu thật để thử chức năng phá hủy hoặc trang trí UI. Không reset DB thật theo một quyết định reset đã dùng trong quá khứ.

## Quy đổi giao dịch ngân hàng USD

Khi phân loại thông báo USD, giữ nguyên số tiền nguồn và ghi sổ VND theo tỷ giá cố định 1 USD = 27,000 VND. Lưu số gốc (cent USD), loại tiền nguồn và tỷ giá trong provenance `bank_source`; số tiền giao dịch dùng VND và tham gia tổng/biểu đồ VND đúng một lần. Tài khoản ghi sổ phải là VND. Form hiển thị số USD gốc và số VND quy đổi; chi tiết giao dịch giữ thông tin nguồn. Ví dụ 22.22 USD = 599,940 VND; 0.01 USD = 270 VND. Không đổi các giao dịch đã xác nhận trước đây; retry không tạo trùng.

## Số người đã trả khi tạo/sửa Share Bill

`initial_paid_people` là số đã trả ban đầu, tối thiểu 1 là chủ bill; không tạo dòng Thu nhập cho phần này. Trường Số người đã trả khi sửa hiển thị tổng tiến độ, bao gồm các lần nhận hiện có. Nếu sửa tổng đã trả thành P, số ban đầu được lưu bằng P trừ tổng số người trong các lần nhận; kết quả phải ít nhất 1. Xóa/sửa lần nhận chỉ trừ/thay phần của lần nhận, giữ số đã trả ban đầu. Tổng số người có thể sửa và gồm cả chủ bill.

Số tiền đã nhận lấy từ giao dịch thực tế. Nhãn Chi − nhận lại thể hiện tổng chi trừ tiền thực nhận, không mặc định là tiền nhóm còn nợ vì phần của chủ bill không phải khoản thu.

## Trình bày và thống kê Share Bill

- Khi bật Nhận Share Bill trong form Thu nhập hoặc phân loại tiền vào, ẩn toàn bộ chọn Danh mục và Tag (kể cả tạo tag mới); tự dùng danh mục Nhận share bill. Thanh gạt, chọn bill và số người đặt trước phần phân loại thường để hạn chế cuộn. Tắt thì hiện lại phân loại thường. Sửa giao dịch đã liên kết cũng dùng giao diện gọn.
- Phần chi cá nhân = số tiền chi gốc − tổng số tiền thực nhận chưa xóa của đúng bill. Không chia đều theo số người; không cần làm tròn phép chia. Ví dụ bill 500,000 VND, nhận lại 70,000 + 130,000 thì chi cá nhân 300,000 VND. Khi chưa có lần nhận thì toàn bộ bill là chi cá nhân tạm thời. Số người/trạng thái hoàn tất không quyết định số tiền chi. Nếu nhận vượt thì giữ số chi âm, không clamp về 0.
- Payment của bill được cộng bất kể tháng nhận; chi cá nhân nằm trong kỳ của giao dịch chi gốc và được tính lại khi thêm/sửa/xóa lần nhận. Tháng nhận tiền không cộng thêm thu nhập từ Share Bill.
- Tổng quan, chênh lệch, tỷ lệ tiết kiệm, biểu đồ ngày/danh mục/tag và tổng thu/chi trong chi tiết tài khoản dùng cùng quy tắc phần chi. Số dư tài khoản, danh sách/lịch sử và số tiền nguồn ngân hàng giữ dòng tiền thực tế. Chiếu số liệu để báo cáo không sửa amount, nguồn hoặc outbox của giao dịch.

## Debug bộ đọc thông báo ngân hàng

- Người dùng bấm Debug trong Cài đặt Ngân hàng để kiểm tra quyền, thu thập và kết nối. Không tự cấp quyền, bật thu thập hay đổi chủ dữ liệu.
- Nếu mất kết nối và đủ điều kiện, thử kết nối lại; nếu chưa có callback thì thử khởi động lại riêng thành phần bộ đọc PMV, khôi phục trạng thái component ban đầu kể cả sau lần app bị dừng giữa quá trình này. Không xóa hoặc xác nhận/bỏ qua thông báo chờ.
- Không chạy nhiều lần Debug đồng thời. Quá trình có thời hạn khoảng 10 giây; chỉ báo khôi phục thành công khi Android gửi callback đã kết nối, không dựa vào việc gửi yêu cầu thành công.
- Nếu bộ đọc đang kết nối, báo trạng thái đó và đề nghị thử một thông báo mới; không suy diễn đã kết nối thành đã đọc được mọi thông báo ngân hàng. Nếu không phục hồi được, báo rõ và hướng dẫn quyền đọc thông báo; lỗi kẹt phía hệ thống vẫn có thể cần khởi động lại máy. Không bảo đảm Debug luôn thay được reboot.

## Share Bill khi phân loại tiền ra

Màn phân loại biến động Chi tiêu có thanh gạt Chia bill với nhóm, nhập tổng số người (gồm bạn) và Đã trả mặc định 1. Khác nhận Share Bill bên Thu nhập, Chi tiêu vẫn hiển thị Danh mục và Tag để phân loại hoạt động. Không kết hợp tạo Share Bill với hành động Công nợ. Lưu bill, giao dịch ngân hàng, tag và outbox nguyên tử với ID/import key ổn định; retry không tạo thêm bill. Giữ nguồn ngân hàng read-only.
