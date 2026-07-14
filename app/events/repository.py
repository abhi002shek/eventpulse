from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.events.models import Event


class EventRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def list_events(self) -> list[Event]:
        statement = select(Event).order_by(Event.starts_at, Event.public_id)
        return list(self._session.scalars(statement).all())

    def get_event_by_public_id(self, public_id: UUID) -> Event | None:
        statement = select(Event).where(Event.public_id == public_id)
        return self._session.scalar(statement)

    def get_existing_public_ids(self, public_ids: set[UUID]) -> set[UUID]:
        statement = select(Event.public_id).where(Event.public_id.in_(public_ids))
        return set(self._session.scalars(statement).all())

    def add_event(self, event: Event) -> None:
        self._session.add(event)
