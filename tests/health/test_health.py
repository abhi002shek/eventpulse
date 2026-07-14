from fastapi.testclient import TestClient


def test_health_returns_stable_response(client: TestClient) -> None:
    # Arrange, Act
    response = client.get("/health")

    # Assert
    assert response.status_code == 200
    assert response.json() == {
        "status": "healthy",
        "service": "eventpulse-api",
    }
