from collections.abc import Generator
from contextlib import contextmanager
from datetime import UTC, datetime
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.bookings.models import Booking
from app.database.dependencies import get_db_session
from app.database.session import engine
from app.events.models import Event
from app.main import app

FIRST_EVENT_ID = UUID("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
SECOND_EVENT_ID = UUID("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
UNKNOWN_EVENT_ID = UUID("cccccccc-cccc-4ccc-8ccc-cccccccccccc")


@contextmanager
def isolated_event_client() -> Generator[TestClient, None, None]:
    connection = engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection, expire_on_commit=False)

    def override_get_db_session() -> Generator[Session, None, None]:
        yield session

    app.dependency_overrides[get_db_session] = override_get_db_session

    try:
        event_ids = session.scalars(select(Event.id)).all()
        if event_ids:
            session.execute(delete(Booking).where(Booking.event_id.in_(event_ids)))
        session.execute(delete(Event))
        session.flush()
        with TestClient(app) as client:
            yield client
    finally:
        app.dependency_overrides.pop(get_db_session, None)
        session.close()
        transaction.rollback()
        connection.close()


def add_event(
    session: Session,
    public_id: UUID,
    name: str,
    starts_at: datetime,
) -> None:
    session.add(
        Event(
            public_id=public_id,
            name=name,
            description=f"{name} description",
            starts_at=starts_at,
            venue=f"{name} venue",
            total_capacity=100,
            available_capacity=100,
        )
    )
    session.flush()


@pytest.fixture
def event_client() -> Generator[TestClient, None, None]:
    with isolated_event_client() as client:
        yield client


def test_list_events_returns_empty_list_before_events_are_inserted(
    event_client: TestClient,
) -> None:
    # Arrange, Act
    response = event_client.get("/api/v1/events")

    # Assert
    assert response.status_code == 200
    assert response.json() == []


def test_list_events_returns_inserted_events(event_client: TestClient) -> None:
    # Arrange
    session = next(app.dependency_overrides[get_db_session]())
    add_event(session, FIRST_EVENT_ID, "Cloud Workshop", datetime(2026, 1, 2, tzinfo=UTC))

    # Act
    response = event_client.get("/api/v1/events")

    # Assert
    assert response.status_code == 200
    events = response.json()
    assert len(events) == 1
    assert events[0]["public_id"] == str(FIRST_EVENT_ID)
    assert events[0]["name"] == "Cloud Workshop"
    assert "id" not in events[0]


def test_list_events_returns_predictable_order(event_client: TestClient) -> None:
    # Arrange
    session = next(app.dependency_overrides[get_db_session]())
    add_event(session, SECOND_EVENT_ID, "Later Event", datetime(2026, 1, 3, tzinfo=UTC))
    add_event(session, FIRST_EVENT_ID, "Earlier Event", datetime(2026, 1, 2, tzinfo=UTC))

    # Act
    response = event_client.get("/api/v1/events")

    # Assert
    assert response.status_code == 200
    event_ids = [event["public_id"] for event in response.json()]
    assert event_ids == [str(FIRST_EVENT_ID), str(SECOND_EVENT_ID)]


def test_get_event_returns_requested_event(event_client: TestClient) -> None:
    # Arrange
    session = next(app.dependency_overrides[get_db_session]())
    add_event(session, FIRST_EVENT_ID, "Requested Event", datetime(2026, 1, 2, tzinfo=UTC))

    # Act
    response = event_client.get(f"/api/v1/events/{FIRST_EVENT_ID}")

    # Assert
    assert response.status_code == 200
    event = response.json()
    assert event["public_id"] == str(FIRST_EVENT_ID)
    assert event["name"] == "Requested Event"
    assert "id" not in event


def test_get_event_returns_404_for_unknown_uuid(event_client: TestClient) -> None:
    # Arrange, Act
    response = event_client.get(f"/api/v1/events/{UNKNOWN_EVENT_ID}")

    # Assert
    assert response.status_code == 404
    assert response.json() == {"detail": "Event not found"}


def test_get_event_returns_422_for_invalid_uuid(event_client: TestClient) -> None:
    # Arrange, Act
    response = event_client.get("/api/v1/events/not-a-uuid")

    # Assert
    assert response.status_code == 422


def test_event_responses_do_not_expose_internal_integer_ids(event_client: TestClient) -> None:
    # Arrange
    session = next(app.dependency_overrides[get_db_session]())
    add_event(session, FIRST_EVENT_ID, "Public Event", datetime(2026, 1, 2, tzinfo=UTC))

    # Act
    list_response = event_client.get("/api/v1/events")
    detail_response = event_client.get(f"/api/v1/events/{FIRST_EVENT_ID}")

    # Assert
    assert list_response.status_code == 200
    assert detail_response.status_code == 200
    assert "id" not in list_response.json()[0]
    assert "id" not in detail_response.json()
