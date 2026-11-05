import '../database/record.dart';

/// Maps normalized ASCII tag slugs to their official Vietnamese display labels.
///
/// Slugs are stored in SQLite/PostgreSQL per v1 data model; this mapping
/// ensures that user-approved Vietnamese labels are displayed faithfully.
class TagDisplay {
  TagDisplay._();

  static String forRecord(Record? tag) {
    final display = tag?.text('display_name').trim() ?? '';
    return display.isNotEmpty ? display : label(tag?.text('name') ?? '');
  }

  static const Map<String, String> labels = {
    // Ăn uống
    'ansang': 'Ăn sáng',
    'antrua': 'Ăn trưa',
    'antoi': 'Ăn tối',
    'ankhuya': 'Ăn khuya',
    'anvat': 'Ăn vặt',
    'caphe': 'Cà phê',
    'nuocuong': 'Nước uống',
    'douongkhac': 'Đồ uống khác',
    'dicho': 'Đi chợ',
    'dichoi': 'Đi chơi',
    'sieuthithucpham': 'Siêu thị thực phẩm',
    'datdoan': 'Đặt đồ ăn',
    'nhahang': 'Nhà hàng',
    'nhau': 'Nhậu',
    'tiec': 'Tiệc/tụ tập',

    // Đi lại
    'doxang': 'Đổ xăng',
    'xangxe': 'Đổ xăng',
    'xeom': 'Xe ôm',
    'taxi': 'Taxi',
    'guixe': 'Gửi xe',
    'suaxe': 'Sửa xe',

    // Mua sắm
    'quanao': 'Quần áo',
    'giaydep': 'Giày dép',
    'phukien': 'Phụ kiện',
    'docanhan': 'Đồ cá nhân',
    'docanha': 'Đồ cá nhân',
    'dogiadung': 'Đồ gia dụng',
    'dodientu': 'Đồ điện tử',
    'dodungcongviec': 'Đồ dùng công việc',

    // Nhà & hóa đơn
    'tiennha': 'Tiền nhà',
    'tiendiennuoc': 'Tiền Điện + nước',
    'tiendien': 'Tiền điện',
    'tiennuoc': 'Tiền nước',
    'internet': 'Internet',
    'dienthoai4g5g': 'Điện thoại/4G/5G',
    'dienthoai': 'Điện thoại',
    'phidichvu': 'Phí dịch vụ',

    // Giải trí
    'xemphim': 'Xem phim',
    'game': 'Game',
    'nghenhac': 'Nghe nhạc',
    'dangkydichvu': 'Đăng ký dịch vụ',
    'sukienbieudien': 'Sự kiện/biểu diễn',
    'sukien': 'Sự kiện',

    // Sức khỏe
    'khambenh': 'Khám bệnh',
    'thuoc': 'Thuốc',
    'thethao': 'Thể thao',
    'baohiem': 'Bảo hiểm',
    'thucpham': 'Thực phẩm',

    // Gia đình & quà tặng
    'bieubome': 'Biếu bố mẹ',
    'bietbome': 'Biếu bố mẹ',
    'hotronguoithan': 'Hỗ trợ người thân',
    'hotronguoi': 'Hỗ trợ người thân',
    'quatang': 'Quà tặng',
    'sinhnhat': 'Sinh nhật',
    'damcuoi': 'Đám cưới',
    'damtang': 'Đám tang',
    'letet': 'Lễ/Tết',

    // Du lịch
    'dichuyen': 'Di chuyển',
    'dichuyendulch': 'Di chuyển',
    'luutru': 'Lưu trú',
    'anuong': 'Ăn uống',
    'thamquan': 'Tham quan',
    'muaqua': 'Mua quà',
    'tour': 'Tour',

    // Chi khác
    'phinganhang': 'Phí ngân hàng',
    'phigiayto': 'Phí giấy tờ',
    'tuthien': 'Từ thiện',
    'tutthien': 'Từ thiện',
    'chichuaphanloai': 'Chi chưa phân loại',
    'chuaphanloai': 'Chi chưa phân loại',

    // Trả sau
    'shopee': 'Shopee',
    'tiktok': 'TikTok',
    'thetindung': 'Thẻ tín dụng',
    'khac': 'Khác',

    // Công nợ (Chi & Thu)
    'chovay': 'Cho vay',
    'tranno': 'Trả nợ',
    'thuno': 'Thu nợ',
    'vayno': 'Vay nợ',

    // Đầu tư (Chi & Thu)
    'chungkhoan': 'Chứng khoán',
    'chungkhoanthu': 'Chứng khoán',
    'quydautu': 'Quỹ đầu tư',
    'quyutu': 'Quỹ đầu tư',
    'quydaututhu': 'Quỹ đầu tư',
    'crypto': 'Crypto',
    'cryptothu': 'Crypto',
    'vang': 'Vàng',
    'vangthu': 'Vàng',
    'tietkiem': 'Tiết kiệm',
    'tiettkiem': 'Tiết kiệm',
    'tietkiemthu': 'Tiết kiệm',
    'gopvon': 'Góp vốn',
    'gopvonthu': 'Góp vốn',
    'khacdautu': 'Khác',
    'khacdaututhu': 'Khác',

    // Thu: Lương
    'luongchinh': 'Lương chính',
    'phucap': 'Phụ cấp',
    'lamthemgio': 'Làm thêm giờ',

    // Thu: Thưởng
    'thuongthang': 'Thưởng tháng',
    'thuongquy': 'Thưởng quý',
    'thuongtet': 'Thưởng Tết',
    'thuongduan': 'Thưởng dự án',
    'thuongkhac': 'Thưởng khác',

    // Thu: Làm thêm
    'viecngoai': 'Việc ngoài',
    'freelance': 'Freelance',
    'giasu': 'Gia sư',

    // Thu: Được tặng
    'giadinh': 'Gia đình',
    'banbe': 'Bạn bè',
    'nguoiyeu': 'Người yêu',
    'mungtuoi': 'Mừng tuổi',
    'quabangtien': 'Quà bằng tiền',

    // Thu: Thu khác
    'hoantien': 'Hoàn tiền',
    'laitietkiem': 'Lãi tiết kiệm',
    'bandocanhan': 'Bán đồ cá nhân',
    'khacthu': 'Khác',
  };

  /// Returns user-facing label for [slug], or [slug] if not found in dictionary.
  static String label(String slug) => labels[slug] ?? slug;
}
