from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database.dependencies import get_db_session
from app.events.schemas import EventResponse
from app.events.service import EventService

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
    event = EventService(session).get_event(event_id)
    return EventResponse.model_validate(event)
