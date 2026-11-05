import uuid


def test_register_and_login_flow(client):
    unique_user = f"user_{uuid.uuid4().hex[:8]}"
    # 1. Register
    reg_resp = client.post(
        "/v1/auth/register",
        json={"username": unique_user, "password": "SecurePassword123!"},
    )
    assert reg_resp.status_code == 201
    assert reg_resp.json()["status"] == "pending"

    # 2. Duplicate registration fails
    dup_resp = client.post(
        "/v1/auth/register",
        json={"username": unique_user, "password": "SecurePassword123!"},
    )
    assert dup_resp.status_code == 409
    assert dup_resp.json()["code"] == "USERNAME_EXISTS"

    # 3. Login wrong password fails
    wrong_resp = client.post(
        "/v1/auth/login",
        json={"username": unique_user, "password": "WrongPassword!"},
    )
    assert wrong_resp.status_code == 401

    # 4. Login correct password succeeds
    login_resp = client.post(
        "/v1/auth/login",
        json={"username": unique_user, "password": "SecurePassword123!"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["token"]
    assert token is not None
    assert login_resp.json()["user"]["status"] == "pending"

    # 5. Access /v1/me with token
    me_resp = client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    assert me_resp.status_code == 200
    assert me_resp.json()["username"] == unique_user

    # 6. Logout
    logout_resp = client.post("/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert logout_resp.status_code == 200

    # 7. Access /v1/me after logout fails
    me_after = client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    assert me_after.status_code == 401
