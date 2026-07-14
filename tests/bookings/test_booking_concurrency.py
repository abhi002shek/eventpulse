from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from threading import Barrier
from uuid import UUID

from fastapi.testclient import TestClient
from sqlalchemy import delete, func, select

from app.bookings.models import Booking
from app.database.session import SessionLocal
from app.events.models import Event
from app.main import app

CONCURRENT_EVENT_ID = UUID("91000000-0000-4000-8000-000000000001")


def cleanup_event() -> None:
    with SessionLocal.begin() as session:
        event_id = session.scalar(select(Event.id).where(Event.public_id == CONCURRENT_EVENT_ID))
        if event_id is not None:
            session.execute(delete(Booking).where(Booking.event_id == event_id))
        session.execute(delete(Event).where(Event.public_id == CONCURRENT_EVENT_ID))


def create_concurrent_test_event() -> None:
    with SessionLocal.begin() as session:
        session.add(
            Event(
                public_id=CONCURRENT_EVENT_ID,
                name="Concurrent Booking Event",
                description="Concurrency test event",
                starts_at=datetime(2026, 2, 1, 12, 0, tzinfo=UTC),
                venue="Concurrency Venue",
                total_capacity=1,
                available_capacity=1,
            )
        )


def submit_booking(barrier: Barrier) -> int:
    request = {
        "event_id": str(CONCURRENT_EVENT_ID),
        "customer_name": "Concurrent User",
        "customer_email": "concurrent@example.com",
        "quantity": 1,
    }
    barrier.wait()
    with TestClient(app) as client:
        return client.post("/api/v1/bookings", json=request).status_code


def test_concurrent_booking_protection_allows_exactly_one_booking() -> None:
    # Arrange
    cleanup_event()
    create_concurrent_test_event()
    barrier = Barrier(2)

    try:
        # Act
        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(submit_booking, [barrier, barrier]))

        # Assert
        assert sorted(results) == [201, 409]

        with SessionLocal() as session:
            event = session.scalar(select(Event).where(Event.public_id == CONCURRENT_EVENT_ID))
            assert event is not None
            booking_count = session.scalar(
                select(func.count()).select_from(Booking).where(Booking.event_id == event.id)
            )
            assert event.available_capacity == 0
            assert booking_count == 1
    finally:
        cleanup_event()
