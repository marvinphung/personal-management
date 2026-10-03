import re
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher

_hasher = PasswordHash((Argon2Hasher(),))

USERNAME_PATTERN = re.compile(r"^[a-z0-9_.]{3,32}$")


def normalize_username(username: str) -> str:
    cleaned = username.strip().lower()
    if not USERNAME_PATTERN.match(cleaned):
        raise ValueError(
            "Tên đăng nhập phải từ 3 đến 32 ký tự, chỉ gồm chữ thường, số, dấu chấm hoặc gạch dưới"
        )
    return cleaned


def validate_password(password: str) -> None:
    if len(password) < 8 or len(password) > 128:
        raise ValueError("Mật khẩu phải từ 8 đến 128 ký tự")


def hash_password(password: str) -> str:
    validate_password(password)
    return _hasher.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return _hasher.verify(plain_password, hashed_password)
