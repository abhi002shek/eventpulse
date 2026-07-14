from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.bookings.schemas import BookingCreateRequest, BookingResponse
from app.bookings.service import BookingService
from app.database.dependencies import get_db_session

router = APIRouter(prefix="/bookings", tags=["bookings"])


@router.post("", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
def create_booking(
    request: BookingCreateRequest,
    session: Annotated[Session, Depends(get_db_session)],
) -> BookingResponse:
    booking = BookingService(session).create_booking(request)
    return BookingResponse.model_validate(booking)


@router.get("/{booking_id}", response_model=BookingResponse)
def get_booking(
    booking_id: UUID,
    session: Annotated[Session, Depends(get_db_session)],
) -> BookingResponse:
    booking = BookingService(session).get_booking(booking_id)
    return BookingResponse.model_validate(booking)
