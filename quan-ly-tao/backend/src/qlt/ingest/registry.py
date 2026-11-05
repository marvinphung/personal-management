from fastapi import HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from qlt.auth.sessions import hash_token
from qlt.config import get_settings
from qlt.db import get_connection

security = HTTPBearer(auto_error=False)


def get_active_collector(
    credentials: HTTPAuthorizationCredentials | None = Security(security),
) -> dict:
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "UNAUTHORIZED_COLLECTOR", "message": "Yêu cầu xác thực máy chủ thu thập"},
        )

    token = credentials.credentials
    token_hash = hash_token(token)
    settings = get_settings()

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT id, state, epoch, last_heartbeat_at
                FROM {settings.database_schema}.collector_devices
                WHERE credential_hash = %s AND state = 'active';
                """,
                (token_hash,),
            )
            collector = cur.fetchone()

    if not collector:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "COLLECTOR_FENCED", "message": "Thiết bị thu thập chưa kích hoạt hoặc đã bị thu hồi"},
        )

    return dict(collector)
