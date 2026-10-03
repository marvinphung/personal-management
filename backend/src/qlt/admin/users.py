import secrets
import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from qlt.auth.dependencies import require_admin_user
from qlt.auth.passwords import hash_password, validate_password
from qlt.auth.sessions import revoke_all_user_sessions
from qlt.catalog.seeds import seed_user_defaults
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1/admin", tags=["Admin Users"])


class CaptureToggleRequest(BaseModel):
    enabled: bool


class TemporaryPasswordRequest(BaseModel):
    temporary_password: str | None = None


@router.get("/users")
def list_users(
    status_filter: str | None = Query(None, alias="status"),
    admin: dict = Depends(require_admin_user),
):
    settings = get_settings()
    query = f"""
        SELECT id, username, role, status, capture_enabled, capture_epoch,
               must_change_password, deleted_at, created_at
        FROM {settings.database_schema}.users
    """
    params = []
    if status_filter:
        query += " WHERE status = %s"
        params.append(status_filter)
    query += " ORDER BY created_at DESC;"

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            users = cur.fetchall()

    return [
        {
            "id": str(u["id"]),
            "username": u["username"],
            "role": u["role"],
            "status": u["status"],
            "capture_enabled": u["capture_enabled"],
            "capture_epoch": u["capture_epoch"],
            "must_change_password": u["must_change_password"],
            "deleted_at": u["deleted_at"].isoformat() if u["deleted_at"] else None,
            "created_at": u["created_at"].isoformat() if u["created_at"] else None,
        }
        for u in users
    ]


@router.post("/users/{user_id}/approve")
def approve_user(user_id: uuid.UUID, admin: dict = Depends(require_admin_user)):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT status, role FROM {settings.database_schema}.users WHERE id = %s;",
                (str(user_id),),
            )
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

            # Update status to active
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.users
                SET status = 'active'
                WHERE id = %s;
                """,
                (str(user_id),),
            )
            # Idempotently seed default categories and tags
            seed_user_defaults(conn, user_id)
        conn.commit()

    return {"message": "Đã phê duyệt người dùng thành công"}


@router.patch("/users/{user_id}/capture")
def toggle_capture(
    user_id: uuid.UUID,
    req: CaptureToggleRequest,
    admin: dict = Depends(require_admin_user),
):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.users
                SET capture_enabled = %s, capture_epoch = capture_epoch + 1
                WHERE id = %s;
                """,
                (req.enabled, str(user_id)),
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
        conn.commit()

    return {"message": f"Đã {'bật' if req.enabled else 'tắt'} thu thập thông báo"}


@router.post("/users/{user_id}/temporary-password")
def set_temporary_password(
    user_id: uuid.UUID,
    req: TemporaryPasswordRequest,
    admin: dict = Depends(require_admin_user),
):
    temp_pwd = req.temporary_password
    if temp_pwd:
        validate_password(temp_pwd)
    else:
        # Cryptographically secure random temporary password
        temp_pwd = secrets.token_urlsafe(12)

    pwd_hash = hash_password(temp_pwd)
    settings = get_settings()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.users
                SET password_hash = %s, must_change_password = true
                WHERE id = %s;
                """,
                (pwd_hash, str(user_id)),
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
        conn.commit()

    # Revoke all user sessions and widget tokens immediately
    revoke_all_user_sessions(user_id)

    # Return temporary password once to admin
    return {
        "temporary_password": temp_pwd,
        "message": "Mật khẩu tạm thời đã được tạo. Người dùng sẽ phải đổi mật khẩu khi đăng nhập.",
    }


@router.delete("/users/{user_id}")
def soft_delete_user(user_id: uuid.UUID, admin: dict = Depends(require_admin_user)):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT role FROM {settings.database_schema}.users WHERE id = %s;",
                (str(user_id),),
            )
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
            if user["role"] == "admin":
                raise HTTPException(status_code=400, detail="Không thể xóa tài khoản quản trị viên")

            cur.execute(
                f"""
                UPDATE {settings.database_schema}.users
                SET status = 'deleted', deleted_at = NOW(), capture_enabled = false, capture_epoch = capture_epoch + 1
                WHERE id = %s;
                """,
                (str(user_id),),
            )
        conn.commit()

    revoke_all_user_sessions(user_id)
    return {"message": "Đã xóa mềm tài khoản. Đặt trước số tài khoản ngân hàng vẫn được giữ."}


@router.post("/users/{user_id}/restore")
def restore_user(user_id: uuid.UUID, admin: dict = Depends(require_admin_user)):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                UPDATE {settings.database_schema}.users
                SET status = 'active', deleted_at = NULL, capture_epoch = capture_epoch + 1
                WHERE id = %s AND status = 'deleted';
                """,
                (str(user_id),),
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản đã xóa")
        conn.commit()

    return {"message": "Đã khôi phục tài khoản thành công"}


@router.post("/users/{user_id}/purge")
def purge_user(user_id: uuid.UUID, admin: dict = Depends(require_admin_user)):
    settings = get_settings()
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT role, status FROM {settings.database_schema}.users WHERE id = %s;",
                (str(user_id),),
            )
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
            if user["role"] == "admin":
                raise HTTPException(status_code=400, detail="Không thể xóa vĩnh viễn quản trị viên")
            if user["status"] != "deleted":
                raise HTTPException(status_code=400, detail="Chỉ có thể xóa vĩnh viễn tài khoản đã xóa mềm")

            # Hard delete from users table (cascades to bindings, categories, transactions, etc.)
            # Non-content HMAC ingest receipts are preserved!
            cur.execute(
                f"DELETE FROM {settings.database_schema}.users WHERE id = %s;",
                (str(user_id),),
            )
        conn.commit()

    revoke_all_user_sessions(user_id)
    return {"message": "Đã xóa vĩnh viễn người dùng và giải phóng các đăng ký số tài khoản ngân hàng"}
