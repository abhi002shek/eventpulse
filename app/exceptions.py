from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class EventPulseError(Exception):
    """Base class for application-level domain errors."""


class EventNotFoundError(EventPulseError):
    """Raised when a public event identifier does not match an event."""


class BookingNotFoundError(EventPulseError):
    """Raised when a public booking identifier does not match a booking."""


class InsufficientCapacityError(EventPulseError):
    """Raised when a booking request exceeds available event capacity."""


def register_exception_handlers(app: FastAPI) -> None:
    """Register application exception handlers as they are introduced."""

    @app.exception_handler(EventNotFoundError)
    async def handle_event_not_found(
        _request: Request,
        _exc: EventNotFoundError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"detail": "Event not found"},
        )

    @app.exception_handler(BookingNotFoundError)
    async def handle_booking_not_found(
        _request: Request,
        _exc: BookingNotFoundError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"detail": "Booking not found"},
        )

    @app.exception_handler(InsufficientCapacityError)
    async def handle_insufficient_capacity(
        _request: Request,
        _exc: InsufficientCapacityError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={"detail": "Insufficient event capacity"},
        )
