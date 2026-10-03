from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from qlt.auth.sessions import verify_session

security = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Security(security),
) -> dict:
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "UNAUTHORIZED", "message": "Yêu cầu đăng nhập"},
        )
    token = credentials.credentials
    user = verify_session(token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "SESSION_EXPIRED", "message": "Phiên đăng nhập đã hết hạn"},
        )
    user["raw_token"] = token
    return user


def require_active_user(user: dict = Depends(get_current_user)) -> dict:
    if user["status"] == "deleted":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_DELETED", "message": "Tài khoản đã bị xóa"},
        )
    if user["status"] == "pending":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "ACCOUNT_PENDING", "message": "Tài khoản đang chờ duyệt"},
        )
    if user.get("must_change_password"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "MUST_CHANGE_PASSWORD", "message": "Cần đổi mật khẩu trước khi tiếp tục"},
        )
    return user


def require_admin_user(user: dict = Depends(get_current_user)) -> dict:
    if user["role"] != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "FORBIDDEN", "message": "Yêu cầu quyền quản trị viên"},
        )
    return user
