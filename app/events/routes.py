from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.dependencies import get_db_session
from app.events.schemas import EventResponse
from app.events.service import EventNotFoundError, EventService

router = APIRouter(prefix="/events", tags=["events"])


@router.get("", response_model=list[EventResponse])
def list_events(
    session: Annotated[Session, Depends(get_db_session)],
) -> list[EventResponse]:
    events = EventService(session).list_events()
    return [EventResponse.model_validate(event) for event in events]


@router.get("/{event_id}", response_model=EventResponse)
def get_event(
    event_id: UUID,
    session: Annotated[Session, Depends(get_db_session)],
) -> EventResponse:
    try:
        event = EventService(session).get_event(event_id)
    except EventNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        ) from exc

    return EventResponse.model_validate(event)
