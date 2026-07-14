from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class EventResponse(BaseModel):
    public_id: UUID
    name: str
    description: str | None
    starts_at: datetime
    venue: str
    total_capacity: int
    available_capacity: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
