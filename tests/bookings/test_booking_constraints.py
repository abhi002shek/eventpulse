from datetime import UTC, datetime
from uuid import uuid4

import pytest
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError

from app.bookings.models import Booking
from app.database.session import SessionLocal
from app.events.models import Event


def test_booking_quantity_constraint_rejects_invalid_value() -> None:
    # Arrange
    event_public_id = uuid4()

    try:
        with SessionLocal.begin() as session:
            event = Event(
                public_id=event_public_id,
                name="Constraint Test Event",
                description=None,
                starts_at=datetime(2026, 2, 1, 12, 0, tzinfo=UTC),
                venue="Constraint Venue",
                total_capacity=10,
                available_capacity=10,
            )
            session.add(event)
            session.flush()
            event_id = event.id

        invalid_booking = Booking(
            event_id=event_id,
            customer_name="Constraint User",
            customer_email="constraint@example.com",
            quantity=0,
            status="confirmed",
        )

        # Act, Assert
        with pytest.raises(IntegrityError):
            with SessionLocal.begin() as session:
                session.add(invalid_booking)
    finally:
        with SessionLocal.begin() as session:
            event = session.scalar(select(Event).where(Event.public_id == event_public_id))
            if event is not None:
                session.execute(delete(Booking).where(Booking.event_id == event.id))
                session.delete(event)


def test_booking_status_constraint_rejects_unsupported_value() -> None:
    # Arrange
    event_public_id = uuid4()

    try:
        with SessionLocal.begin() as session:
            event = Event(
                public_id=event_public_id,
                name="Status Constraint Event",
                description=None,
                starts_at=datetime(2026, 2, 1, 12, 0, tzinfo=UTC),
                venue="Constraint Venue",
                total_capacity=10,
                available_capacity=10,
            )
            session.add(event)
            session.flush()
            event_id = event.id

        invalid_booking = Booking(
            event_id=event_id,
            customer_name="Constraint User",
            customer_email="constraint@example.com",
            quantity=1,
            status="cancelled",
        )

        # Act, Assert
        with pytest.raises(IntegrityError):
            with SessionLocal.begin() as session:
                session.add(invalid_booking)
    finally:
        with SessionLocal.begin() as session:
            event = session.scalar(select(Event).where(Event.public_id == event_public_id))
            if event is not None:
                session.execute(delete(Booking).where(Booking.event_id == event.id))
                session.delete(event)
