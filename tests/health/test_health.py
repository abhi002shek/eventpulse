from fastapi.testclient import TestClient

from app.main import app


def test_health_returns_stable_response() -> None:
    # Arrange
    client = TestClient(app)

    # Act
    response = client.get("/health")

    # Assert
    assert response.status_code == 200
    assert response.json() == {
        "status": "healthy",
        "service": "eventpulse-api",
    }
