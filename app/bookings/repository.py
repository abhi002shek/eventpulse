from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.bookings.models import Booking
from app.events.models import Event


class BookingRepository:
    def __init__(self, session: Session) -> None:
        self._session = session

    def get_event_for_booking(self, event_public_id: UUID) -> Event | None:
        statement = (
            select(Event).where(Event.public_id == event_public_id).with_for_update(of=Event)
        )
        return self._session.scalar(statement)

    def add_booking(self, booking: Booking) -> None:
        self._session.add(booking)

    def get_booking_by_public_id(self, booking_public_id: UUID) -> tuple[Booking, Event] | None:
        statement = (
            select(Booking, Event)
            .join(Event, Booking.event_id == Event.id)
            .where(Booking.public_id == booking_public_id)
        )
        row = self._session.execute(statement).one_or_none()
        if row is None:
            return None
        return row.Booking, row.Event

    def count_bookings_for_event(self, event_id: int) -> int:
        statement = select(func.count()).select_from(Booking).where(Booking.event_id == event_id)
        return self._session.scalar(statement) or 0
