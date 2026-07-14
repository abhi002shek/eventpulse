from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class BookingCreateRequest(BaseModel):
    event_id: UUID
    customer_name: str = Field(min_length=1, max_length=120)
    customer_email: EmailStr
    quantity: int = Field(ge=1)


class BookingResponse(BaseModel):
    public_id: UUID
    event_id: UUID
    quantity: int
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
