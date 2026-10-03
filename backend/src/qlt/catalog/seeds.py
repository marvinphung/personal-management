import unicodedata
import uuid
import psycopg
from qlt.config import get_settings


def make_key(text: str) -> str:
    """Normalize name for uniqueness: lowercased, trimmed, accents stripped, non-alphanumeric converted to underscore."""
    text = text.strip().lower()
    # Normalize unicode to NFD and drop combining accents
    nfkd = unicodedata.normalize("NFKD", text)
    ascii_text = "".join(c for c in nfkd if not unicodedata.combining(c))
    result = []
    for c in ascii_text:
        if c.isalnum():
            result.append(c)
        elif result and result[-1] != "_":
            result.append("_")
    return "".join(result).strip("_")


DEFAULT_EXPENSE_CATEGORIES = [
    ("Ăn uống", ["Ăn sáng", "Ăn trưa", "Ăn tối", "Cà phê"], "restaurant", 1),
    ("Đi lại", ["Xăng xe", "Gửi xe", "Taxi", "Xe công nghệ"], "commute", 2),
    ("Mua sắm", ["Quần áo", "Đồ cá nhân", "Đồ gia dụng"], "shopping_bag", 3),
    ("Nhà & hóa đơn", ["Tiền nhà", "Điện", "Nước", "Internet"], "home", 4),
    ("Giải trí", ["Xem phim", "Game", "Đi chơi"], "sports_esports", 5),
    ("Sức khỏe", ["Thuốc", "Khám bệnh", "Thể thao"], "health_and_safety", 6),
    ("Học tập", ["Học phí", "Sách", "Khóa học"], "school", 7),
    ("Gia đình & quà tặng", ["Gia đình", "Quà tặng", "Hiếu hỉ"], "redeem", 8),
    ("Du lịch", ["Vé xe/máy bay", "Lưu trú"], "flight", 9),
    ("Chi khác", [], "more_horiz", 10),
]

DEFAULT_INCOME_CATEGORIES = [
    ("Lương", ["Lương chính", "Phụ cấp", "Làm thêm giờ"], "payments", 1),
    ("Thưởng", ["Thưởng tháng", "Thưởng quý", "Thưởng Tết"], "stars", 2),
    ("Kinh doanh", ["Bán hàng", "Dịch vụ"], "store", 3),
    ("Làm thêm", ["Freelance", "Dạy học", "Công việc phụ"], "work", 4),
    ("Được tặng", ["Gia đình", "Bạn bè", "Mừng tuổi"], "card_giftcard", 5),
    ("Thu khác", ["Hoàn tiền", "Khác"], "attach_money", 6),
]


def seed_user_defaults(conn: psycopg.Connection, user_id: uuid.UUID) -> None:
    settings = get_settings()
    schema = settings.database_schema

    with conn.cursor() as cur:
        # Check if already seeded to ensure idempotency
        cur.execute(
            f"SELECT COUNT(*) AS count FROM {schema}.categories WHERE user_id = %s;",
            (str(user_id),),
        )
        row = cur.fetchone()
        count = row["count"] if isinstance(row, dict) else row[0]
        if count > 0:
            return  # Already seeded

        # Expense categories and tags
        for cat_name, tags, icon, rank in DEFAULT_EXPENSE_CATEGORIES:
            cat_id = uuid.uuid4()
            cat_key = make_key(cat_name)
            cur.execute(
                f"""
                INSERT INTO {schema}.categories (
                    id, user_id, direction, name, name_key, icon, seed_rank
                ) VALUES (%s, %s, 'expense', %s, %s, %s, %s);
                """,
                (str(cat_id), str(user_id), cat_name, cat_key, icon, rank),
            )
            for tag_name in tags:
                tag_id = uuid.uuid4()
                tag_key = make_key(tag_name)
                cur.execute(
                    f"""
                    INSERT INTO {schema}.tags (
                        id, user_id, category_id, name, name_key
                    ) VALUES (%s, %s, %s, %s, %s);
                    """,
                    (str(tag_id), str(user_id), str(cat_id), tag_name, tag_key),
                )

        # Income categories and tags
        for cat_name, tags, icon, rank in DEFAULT_INCOME_CATEGORIES:
            cat_id = uuid.uuid4()
            cat_key = make_key(cat_name)
            cur.execute(
                f"""
                INSERT INTO {schema}.categories (
                    id, user_id, direction, name, name_key, icon, seed_rank
                ) VALUES (%s, %s, 'income', %s, %s, %s, %s);
                """,
                (str(cat_id), str(user_id), cat_name, cat_key, icon, rank),
            )
            for tag_name in tags:
                tag_id = uuid.uuid4()
                tag_key = make_key(tag_name)
                cur.execute(
                    f"""
                    INSERT INTO {schema}.tags (
                        id, user_id, category_id, name, name_key
                    ) VALUES (%s, %s, %s, %s, %s);
                    """,
                    (str(tag_id), str(user_id), str(cat_id), tag_name, tag_key),
                )
