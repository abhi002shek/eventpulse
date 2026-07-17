from fastapi.testclient import TestClient


def test_metrics_endpoint_exposes_eventpulse_metrics(client: TestClient) -> None:
    # Arrange
    client.get("/health")

    # Act
    response = client.get("/metrics")

    # Assert
    assert response.status_code == 200
    assert "eventpulse_http_requests_total" in response.text
    assert 'path="/health"' in response.text
