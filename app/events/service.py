from uuid import UUID

from sqlalchemy.orm import Session

from app.events.models import Event
from app.events.repository import EventRepository


class EventNotFoundError(Exception):
    """Raised when a public event identifier does not match an event."""


class EventService:
    def __init__(self, session: Session) -> None:
        self._repository = EventRepository(session)

    def list_events(self) -> list[Event]:
        return self._repository.list_events()

    def get_event(self, event_id: UUID) -> Event:
        event = self._repository.get_event_by_public_id(event_id)
        if event is None:
            raise EventNotFoundError
        return event
