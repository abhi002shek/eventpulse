from fastapi.testclient import TestClient

from app.database.dependencies import database_is_available
from app.main import app


def test_ready_returns_available_when_database_is_reachable(client: TestClient) -> None:
    # Arrange, Act
    response = client.get("/ready")

    # Assert
    assert response.status_code == 200
    assert response.json() == {
        "status": "ready",
        "dependencies": {"database": "available"},
    }


def test_ready_returns_unavailable_when_database_check_fails(client: TestClient) -> None:
    # Arrange
    app.dependency_overrides[database_is_available] = lambda: False

    try:
        # Act
        response = client.get("/ready")
    finally:
        app.dependency_overrides.clear()

    # Assert
    assert response.status_code == 503
    assert response.json() == {
        "status": "not_ready",
        "dependencies": {"database": "unavailable"},
    }


def test_ready_failure_response_does_not_expose_database_details(client: TestClient) -> None:
    # Arrange
    app.dependency_overrides[database_is_available] = lambda: False

    try:
        # Act
        response = client.get("/ready")
    finally:
        app.dependency_overrides.clear()

    # Assert
    response_body = response.text
    assert "eventpulse_dev_password" not in response_body
    assert "DATABASE_PASSWORD" not in response_body
    assert "postgresql" not in response_body
    assert "SELECT 1" not in response_body
