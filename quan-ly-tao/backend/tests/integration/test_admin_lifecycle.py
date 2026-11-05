import uuid
import psycopg
from qlt.auth.passwords import hash_password
from qlt.auth.sessions import create_session
from qlt.config import get_settings


def create_test_admin():
    settings = get_settings()
    admin_id = uuid.uuid4()
    username = f"admin_{admin_id.hex[:8]}"
    pwd_hash = hash_password("AdminSuperPass123!")

    with psycopg.connect(settings.database_url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {settings.database_schema}.users (
                    id, username, password_hash, role, status
                ) VALUES (%s, %s, %s, 'admin', 'active');
                """,
                (str(admin_id), username, pwd_hash),
            )
    token, _ = create_session(admin_id, scope="admin")
    return admin_id, token


def test_admin_approve_and_lifecycle(client):
    admin_id, admin_token = create_test_admin()
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 1. Register a normal user
    unique_user = f"user_{uuid.uuid4().hex[:8]}"
    reg_resp = client.post(
        "/v1/auth/register",
        json={"username": unique_user, "password": "UserPass12345!"},
    )
    assert reg_resp.status_code == 201
    user_id = reg_resp.json()["user_id"]

    # 2. Admin approves user
    approve_resp = client.post(f"/v1/admin/users/{user_id}/approve", headers=admin_headers)
    assert approve_resp.status_code == 200

    # Verify categories and tags were seeded idempotently
    approve_again = client.post(f"/v1/admin/users/{user_id}/approve", headers=admin_headers)
    assert approve_again.status_code == 200

    # 3. Capture toggle
    toggle_resp = client.patch(
        f"/v1/admin/users/{user_id}/capture",
        json={"enabled": False},
        headers=admin_headers,
    )
    assert toggle_resp.status_code == 200

    # 4. Set temporary password
    temp_resp = client.post(
        f"/v1/admin/users/{user_id}/temporary-password",
        json={},
        headers=admin_headers,
    )
    assert temp_resp.status_code == 200
    temp_pwd = temp_resp.json()["temporary_password"]
    assert temp_pwd is not None

    # Login with temporary password forces password change
    login_resp = client.post("/v1/auth/login", json={"username": unique_user, "password": temp_pwd})
    assert login_resp.status_code == 200
    assert login_resp.json()["user"]["must_change_password"] is True

    # 5. Soft delete
    del_resp = client.delete(f"/v1/admin/users/{user_id}", headers=admin_headers)
    assert del_resp.status_code == 200

    # Login should now fail with 403 ACCOUNT_DELETED
    login_deleted = client.post("/v1/auth/login", json={"username": unique_user, "password": temp_pwd})
    assert login_deleted.status_code == 403
    assert login_deleted.json()["code"] == "ACCOUNT_DELETED"

    # 6. Restore
    restore_resp = client.post(f"/v1/admin/users/{user_id}/restore", headers=admin_headers)
    assert restore_resp.status_code == 200

    # 7. Soft delete again and Purge
    client.delete(f"/v1/admin/users/{user_id}", headers=admin_headers)
    purge_resp = client.post(f"/v1/admin/users/{user_id}/purge", headers=admin_headers)
    assert purge_resp.status_code == 200

    # User can now register again with the same username
    rereg_resp = client.post(
        "/v1/auth/register",
        json={"username": unique_user, "password": "UserPass12345!"},
    )
    assert rereg_resp.status_code == 201
