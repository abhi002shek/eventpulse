from datetime import UTC, datetime
from uuid import uuid4

import pytest
from sqlalchemy.exc import IntegrityError

from app.database.session import SessionLocal
from app.events.models import Event


@pytest.mark.parametrize(
    ("total_capacity", "available_capacity"),
    [
        (0, 0),
        (10, -1),
        (10, 11),
    ],
)
def test_event_capacity_constraints_reject_invalid_values(
    total_capacity: int,
    available_capacity: int,
) -> None:
    # Arrange
    event = Event(
        public_id=uuid4(),
        name="Invalid Capacity Event",
        description=None,
        starts_at=datetime(2026, 1, 2, tzinfo=UTC),
        venue="Test Venue",
        total_capacity=total_capacity,
        available_capacity=available_capacity,
    )

    # Act, Assert
    with pytest.raises(IntegrityError):
        with SessionLocal.begin() as session:
            session.add(event)
