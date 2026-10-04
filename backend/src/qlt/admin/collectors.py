import secrets
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Response, status
from pydantic import BaseModel, Field

from qlt.auth.dependencies import require_admin_user
from qlt.auth.sessions import hash_token
from qlt.config import get_settings
from qlt.db import get_connection

router = APIRouter(prefix="/v1/admin/collectors", tags=["Admin Collectors"])


class CollectorEnrollmentRequest(BaseModel):
    handover: bool = Field(
        default=False,
        description="Retire the current collector and increment its fencing epoch.",
    )


class CollectorBinding(BaseModel):
    binding_id: uuid.UUID
    bank_code: str
    account_number: str
    binding_version: int
    capture_epoch: int


class CollectorEnrollmentResponse(BaseModel):
    collector_id: uuid.UUID
    collector_token: str
    credential_type: str = "Bearer"
    collector_epoch: int
    state: str
    handover_performed: bool
    issued_at: datetime
    token_displayed_once: bool = True
    bindings: list[CollectorBinding]


@router.post(
    "/enroll",
    response_model=CollectorEnrollmentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Issue a one-time collector credential",
)
def enroll_collector(
    request: CollectorEnrollmentRequest,
    response: Response,
    admin: dict = Depends(require_admin_user),
):
    """Issue a credential while changing the fencing epoch only for a handover."""
    del admin
    settings = get_settings()
    schema = settings.database_schema
    collector_token = f"qlt_collector_{secrets.token_urlsafe(32)}"
    credential_hash = hash_token(collector_token)

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Serialize enrollment requests. The table-level lock also covers the
            # first enrollment, where no active row exists to lock.
            cur.execute(f"LOCK TABLE {schema}.collector_devices IN EXCLUSIVE MODE")
            cur.execute(
                f"""
                SELECT id, epoch
                FROM {schema}.collector_devices
                WHERE state = 'active'
                FOR UPDATE;
                """
            )
            active = cur.fetchone()
            handover_performed = bool(request.handover and active)

            if active and not request.handover:
                cur.execute(
                    f"""
                    UPDATE {schema}.collector_devices
                    SET credential_hash = %s
                    WHERE id = %s
                    RETURNING id, epoch, state, created_at;
                    """,
                    (credential_hash, str(active["id"])),
                )
                collector = cur.fetchone()
            else:
                next_epoch = int(active["epoch"]) + 1 if active else 1
                if active:
                    cur.execute(
                        f"""
                        UPDATE {schema}.collector_devices
                        SET state = 'retired'
                        WHERE id = %s;
                        """,
                        (str(active["id"]),),
                    )
                cur.execute(
                    f"""
                    INSERT INTO {schema}.collector_devices (credential_hash, state, epoch)
                    VALUES (%s, 'active', %s)
                    RETURNING id, epoch, state, created_at;
                    """,
                    (credential_hash, next_epoch),
                )
                collector = cur.fetchone()

            cur.execute(
                f"""
                SELECT b.id AS binding_id, b.bank_code, b.account_number,
                       b.version AS binding_version, u.capture_epoch
                FROM {schema}.bank_bindings b
                JOIN {schema}.users u ON b.user_id = u.id
                WHERE u.status = 'active' AND u.capture_enabled = true
                ORDER BY b.bank_code, b.account_number;
                """
            )
            bindings = cur.fetchall()
        conn.commit()

    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    return {
        "collector_id": collector["id"],
        "collector_token": collector_token,
        "collector_epoch": collector["epoch"],
        "state": collector["state"],
        "handover_performed": handover_performed,
        "issued_at": datetime.now(timezone.utc),
        "bindings": [dict(binding) for binding in bindings],
    }
