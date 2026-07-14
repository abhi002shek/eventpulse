from typing import TypedDict

from fastapi import APIRouter

from app.configuration.settings import get_settings


class HealthResponse(TypedDict):
    status: str
    service: str


router = APIRouter()


@router.get("/health", response_model=None)
def get_health() -> HealthResponse:
    settings = get_settings()
    return {"status": "healthy", "service": settings.service_name}
