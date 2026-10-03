from unittest.mock import patch


def test_health_live(client):
    response = client.get("/v1/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_health_ready_when_connected(client):
    with patch("qlt.main.check_db_ready", return_value=True):
        response = client.get("/v1/health/ready")
        assert response.status_code == 200
        assert response.json() == {"status": "ready", "database": "connected"}


def test_health_ready_when_disconnected(client):
    with patch("qlt.main.check_db_ready", return_value=False):
        response = client.get("/v1/health/ready")
        assert response.status_code == 503
        assert response.json() == {"status": "not_ready", "database": "disconnected"}
