import uuid

import psycopg

from qlt.auth.passwords import hash_password
from qlt.auth.sessions import create_session, verify_session
from qlt.config import get_settings


def _auth_headers(role: str = "admin") -> dict[str, str]:
    settings = get_settings()
    admin_id = uuid.uuid4()
    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.users
                    (id, username, password_hash, role, status)
                VALUES (%s, %s, %s, %s, 'active');
                """,
                (
                    str(admin_id),
                    f"enroll_{role}_{admin_id.hex[:8]}",
                    hash_password("AdminPass#2026"),
                    role,
                ),
            )
    token, _ = create_session(admin_id, scope=role)
    assert verify_session(token)["role"] == role
    return {"Authorization": f"Bearer {token}"}


def test_collector_enrollment_is_admin_only(client):
    response = client.post("/v1/admin/collectors/enroll", json={})
    assert response.status_code == 401
    response = client.post(
        "/v1/admin/collectors/enroll", json={}, headers=_auth_headers("user")
    )
    assert response.status_code == 403


def test_enrollment_rotates_token_without_epoch_and_handover_increments_epoch(client):
    settings = get_settings()
    headers = _auth_headers()
    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(f"DELETE FROM {settings.database_schema}.collector_devices")

    first = client.post("/v1/admin/collectors/enroll", json={}, headers=headers)
    assert first.status_code == 201, first.text
    first_body = first.json()
    assert first.headers["cache-control"] == "no-store"
    assert first_body["collector_epoch"] == 1
    assert first_body["handover_performed"] is False
    assert first_body["token_displayed_once"] is True
    assert first_body["collector_token"].startswith("qlt_collector_")

    first_collector_headers = {"Authorization": f"Bearer {first_body['collector_token']}"}
    assert client.get("/v1/collector/registry", headers=first_collector_headers).status_code == 200

    rotation = client.post(
        "/v1/admin/collectors/enroll", json={"handover": False}, headers=headers
    )
    rotation_body = rotation.json()
    assert rotation.status_code == 201
    assert rotation_body["collector_id"] == first_body["collector_id"]
    assert rotation_body["collector_epoch"] == first_body["collector_epoch"]
    assert rotation_body["collector_token"] != first_body["collector_token"]
    assert client.get("/v1/collector/registry", headers=first_collector_headers).status_code == 401

    handover = client.post(
        "/v1/admin/collectors/enroll", json={"handover": True}, headers=headers
    )
    handover_body = handover.json()
    assert handover.status_code == 201
    assert handover_body["collector_id"] != first_body["collector_id"]
    assert handover_body["collector_epoch"] == first_body["collector_epoch"] + 1
    assert handover_body["handover_performed"] is True

    current_headers = {"Authorization": f"Bearer {handover_body['collector_token']}"}
    registry = client.get("/v1/collector/registry", headers=current_headers)
    assert registry.status_code == 200
    assert registry.json()["collector_epoch"] == handover_body["collector_epoch"]
