from collections.abc import Generator
from datetime import UTC, datetime
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete, select

from app.bookings.models import Booking
from app.database.session import SessionLocal
from app.events.models import Event
from app.main import app

EVENT_ID = UUID("90000000-0000-4000-8000-000000000001")
UNKNOWN_EVENT_ID = UUID("90000000-0000-4000-8000-000000000099")
UNKNOWN_BOOKING_ID = UUID("90000000-0000-4000-8000-000000000098")


def create_event(
    public_id: UUID = EVENT_ID,
    total_capacity: int = 10,
    available_capacity: int = 10,
) -> Event:
    with SessionLocal.begin() as session:
        event = Event(
            public_id=public_id,
            name="Booking Test Event",
            description="Booking route test event",
            starts_at=datetime(2026, 2, 1, 12, 0, tzinfo=UTC),
            venue="Booking Test Venue",
            total_capacity=total_capacity,
            available_capacity=available_capacity,
        )
        session.add(event)
        session.flush()
        session.expunge(event)
        return event


def cleanup_events(public_ids: set[UUID]) -> None:
    with SessionLocal.begin() as session:
        event_ids = session.scalars(select(Event.id).where(Event.public_id.in_(public_ids))).all()
        if event_ids:
            session.execute(delete(Booking).where(Booking.event_id.in_(event_ids)))
        session.execute(delete(Event).where(Event.public_id.in_(public_ids)))


@pytest.fixture
def booking_client() -> Generator[TestClient, None, None]:
    cleanup_events({EVENT_ID, UNKNOWN_EVENT_ID})
    with TestClient(app) as client:
        yield client
    cleanup_events({EVENT_ID, UNKNOWN_EVENT_ID})


def booking_request(event_id: UUID = EVENT_ID, quantity: int = 2) -> dict[str, object]:
    return {
        "event_id": str(event_id),
        "customer_name": "Demo User",
        "customer_email": "demo@example.com",
        "quantity": quantity,
    }


def get_event(public_id: UUID = EVENT_ID) -> Event:
    with SessionLocal() as session:
        event = session.scalar(select(Event).where(Event.public_id == public_id))
        assert event is not None
        session.expunge(event)
        return event


def test_create_booking_returns_201(booking_client: TestClient) -> None:
    # Arrange
    create_event()

    # Act
    response = booking_client.post("/api/v1/bookings", json=booking_request())

    # Assert
    assert response.status_code == 201
    booking = response.json()
    assert booking["event_id"] == str(EVENT_ID)
    assert booking["quantity"] == 2
    assert booking["status"] == "confirmed"


def test_create_booking_decrements_event_availability(booking_client: TestClient) -> None:
    # Arrange
    create_event(available_capacity=10)

    # Act
    response = booking_client.post("/api/v1/bookings", json=booking_request(quantity=3))

    # Assert
    assert response.status_code == 201
    event = get_event()
    assert event.available_capacity == 7


def test_booking_response_does_not_expose_internal_ids_or_email(
    booking_client: TestClient,
) -> None:
    # Arrange
    create_event()

    # Act
    response = booking_client.post("/api/v1/bookings", json=booking_request())

    # Assert
    assert response.status_code == 201
    booking = response.json()
    assert "id" not in booking
    assert "event_internal_id" not in booking
    assert "customer_email" not in booking


def test_create_booking_returns_404_for_unknown_event(booking_client: TestClient) -> None:
    # Arrange, Act
    response = booking_client.post(
        "/api/v1/bookings",
        json=booking_request(event_id=UNKNOWN_EVENT_ID),
    )

    # Assert
    assert response.status_code == 404
    assert response.json() == {"detail": "Event not found"}


def test_create_booking_returns_409_when_quantity_exceeds_availability(
    booking_client: TestClient,
) -> None:
    # Arrange
    create_event(available_capacity=1)

    # Act
    response = booking_client.post("/api/v1/bookings", json=booking_request(quantity=2))

    # Assert
    assert response.status_code == 409
    assert response.json() == {"detail": "Insufficient event capacity"}


@pytest.mark.parametrize("quantity", [0, -1])
def test_create_booking_returns_422_for_non_positive_quantity(
    booking_client: TestClient,
    quantity: int,
) -> None:
    # Arrange
    create_event()

    # Act
    response = booking_client.post("/api/v1/bookings", json=booking_request(quantity=quantity))

    # Assert
    assert response.status_code == 422


def test_create_booking_returns_422_for_invalid_email(booking_client: TestClient) -> None:
    # Arrange
    create_event()
    request = booking_request()
    request["customer_email"] = "not-an-email"

    # Act
    response = booking_client.post("/api/v1/bookings", json=request)

    # Assert
    assert response.status_code == 422


def test_get_booking_returns_requested_booking(booking_client: TestClient) -> None:
    # Arrange
    create_event()
    create_response = booking_client.post("/api/v1/bookings", json=booking_request())
    booking_id = create_response.json()["public_id"]

    # Act
    response = booking_client.get(f"/api/v1/bookings/{booking_id}")

    # Assert
    assert response.status_code == 200
    booking = response.json()
    assert booking["public_id"] == booking_id
    assert booking["event_id"] == str(EVENT_ID)
    assert "id" not in booking
    assert "customer_email" not in booking


def test_get_booking_returns_404_for_unknown_uuid(booking_client: TestClient) -> None:
    # Arrange, Act
    response = booking_client.get(f"/api/v1/bookings/{UNKNOWN_BOOKING_ID}")

    # Assert
    assert response.status_code == 404
    assert response.json() == {"detail": "Booking not found"}


def test_get_booking_returns_422_for_invalid_uuid(booking_client: TestClient) -> None:
    # Arrange, Act
    response = booking_client.get("/api/v1/bookings/not-a-uuid")

    # Assert
    assert response.status_code == 422


def test_failed_booking_does_not_change_event_capacity(booking_client: TestClient) -> None:
    # Arrange
    create_event(available_capacity=1)

    # Act
    response = booking_client.post("/api/v1/bookings", json=booking_request(quantity=2))

    # Assert
    assert response.status_code == 409
    event = get_event()
    assert event.available_capacity == 1


def test_create_booking_returns_422_for_malformed_event_uuid(
    booking_client: TestClient,
) -> None:
    # Arrange
    request = booking_request()
    request["event_id"] = "not-a-uuid"

    # Act
    response = booking_client.post("/api/v1/bookings", json=request)

    # Assert
    assert response.status_code == 422
