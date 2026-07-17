from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from sqlalchemy.orm import Session

from app.bookings.models import BOOKING_STATUS_CONFIRMED, Booking
from app.bookings.repository import BookingRepository
from app.bookings.schemas import BookingCreateRequest
from app.exceptions import BookingNotFoundError, EventNotFoundError, InsufficientCapacityError
from app.metrics import record_booking_result


@dataclass(frozen=True)
class BookingResult:
    public_id: UUID
    event_id: UUID
    quantity: int
    status: str
    created_at: datetime


class BookingService:
    def __init__(self, session: Session) -> None:
        self._session = session
        self._repository = BookingRepository(session)

    def create_booking(self, request: BookingCreateRequest) -> BookingResult:
        with self._session.begin():
            event = self._repository.get_event_for_booking(request.event_id)
            if event is None:
                record_booking_result("event_not_found")
                raise EventNotFoundError

            if event.available_capacity < request.quantity:
                record_booking_result("insufficient_capacity")
                raise InsufficientCapacityError

            booking = Booking(
                event_id=event.id,
                customer_name=request.customer_name,
                customer_email=str(request.customer_email),
                quantity=request.quantity,
                status=BOOKING_STATUS_CONFIRMED,
            )
            event.available_capacity -= request.quantity
            self._repository.add_booking(booking)
            self._session.flush()
            record_booking_result("confirmed")

            return BookingResult(
                public_id=booking.public_id,
                event_id=event.public_id,
                quantity=booking.quantity,
                status=booking.status,
                created_at=booking.created_at,
            )

    def get_booking(self, booking_id: UUID) -> BookingResult:
        booking_with_event = self._repository.get_booking_by_public_id(booking_id)
        if booking_with_event is None:
            raise BookingNotFoundError

        booking, event = booking_with_event
        return BookingResult(
            public_id=booking.public_id,
            event_id=event.public_id,
            quantity=booking.quantity,
            status=booking.status,
            created_at=booking.created_at,
        )
