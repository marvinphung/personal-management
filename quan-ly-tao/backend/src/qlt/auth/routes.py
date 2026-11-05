import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
import psycopg
from qlt.auth.dependencies import get_current_user
from qlt.auth.passwords import hash_password, normalize_username, validate_password, verify_password
from qlt.auth.sessions import create_session, revoke_all_user_sessions, revoke_session
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1", tags=["Auth"])


class RegisterRequest(BaseModel):
    username: str
    password: str


class LoginRequest(BaseModel):
    username: str
    password: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str


@router.post("/auth/register", status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest):
    try:
        username = normalize_username(req.username)
        validate_password(req.password)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(e)},
        )

    settings = get_settings()
    pwd_hash = hash_password(req.password)
    user_id = uuid.uuid4()

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    INSERT INTO {settings.database_schema}.users (
                        id, username, password_hash, role, status
                    ) VALUES (%s, %s, %s, 'user', 'pending');
                    """,
                    (str(user_id), username, pwd_hash),
                )
            conn.commit()
    except psycopg.errors.UniqueViolation:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "USERNAME_EXISTS", "message": "Tên đăng nhập đã được sử dụng"},
        )

    return {
        "user_id": str(user_id),
        "username": username,
        "status": "pending",
        "message": "Đăng ký thành công, vui lòng chờ quản trị viên phê duyệt",
    }


@router.post("/auth/login")
def login(req: LoginRequest):
    username = req.username.strip().lower()
    settings = get_settings()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT id, username, password_hash, role, status, must_change_password
                FROM {settings.database_schema}.users
                WHERE username = %s;
                """,
                (username,),
            )
            user = cur.fetchone()

    if not user or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_CREDENTIALS", "message": "Tên đăng nhập hoặc mật khẩu không đúng"},
        )

    if user["status"] == "deleted":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_DELETED", "message": "Tài khoản đã bị xóa"},
        )

    token, expires_at = create_session(user["id"], scope=user["role"])

    return {
        "token": token,
        "expires_at": expires_at.isoformat(),
        "user": {
            "id": str(user["id"]),
            "username": user["username"],
            "role": user["role"],
            "status": user["status"],
            "must_change_password": user["must_change_password"],
        },
    }


@router.post("/auth/renew")
def renew(user: dict = Depends(get_current_user)):
    # Renew creates a fresh session token and revokes the old one
    new_token, expires_at = create_session(user["user_id"], scope=user["scope"])
    revoke_session(user["raw_token"])
    return {
        "token": new_token,
        "expires_at": expires_at.isoformat(),
    }


@router.post("/auth/logout")
def logout(user: dict = Depends(get_current_user)):
    revoke_session(user["raw_token"])
    return {"message": "Đã đăng xuất"}


@router.get("/me")
def get_me(user: dict = Depends(get_current_user)):
    return {
        "id": str(user["user_id"]),
        "username": user["username"],
        "role": user["role"],
        "status": user["status"],
        "capture_enabled": user.get("capture_enabled", True),
        "must_change_password": user.get("must_change_password", False),
    }


@router.post("/auth/change-password")
def change_password(req: ChangePasswordRequest, user: dict = Depends(get_current_user)):
    try:
        validate_password(req.new_password)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VALIDATION_ERROR", "message": str(e)},
        )

    settings = get_settings()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT password_hash FROM {settings.database_schema}.users WHERE id = %s;",
                (str(user["user_id"]),),
            )
            row = cur.fetchone()
            if not row or not verify_password(req.old_password, row["password_hash"]):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={"code": "INVALID_PASSWORD", "message": "Mật khẩu hiện tại không đúng"},
                )

            new_hash = hash_password(req.new_password)
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.users
                SET password_hash = %s, must_change_password = false
                WHERE id = %s;
                """,
                (new_hash, str(user["user_id"])),
            )
        conn.commit()

    # Revoke all sessions, create a single new session for this device
    revoke_all_user_sessions(user["user_id"])
    token, expires_at = create_session(user["user_id"], scope=user["scope"])

    return {
        "message": "Đổi mật khẩu thành công",
        "token": token,
        "expires_at": expires_at.isoformat(),
    }
