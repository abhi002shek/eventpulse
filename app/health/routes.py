from typing import Annotated, TypedDict

from fastapi import APIRouter, Depends, status
from fastapi.responses import JSONResponse

from app.configuration.settings import get_settings
from app.database.dependencies import database_is_available


class HealthResponse(TypedDict):
    status: str
    service: str


class DependencyStatus(TypedDict):
    database: str


class ReadinessResponse(TypedDict):
    status: str
    dependencies: DependencyStatus


router = APIRouter()


@router.get("/health", response_model=None)
def get_health() -> HealthResponse:
    settings = get_settings()
    return {"status": "healthy", "service": settings.service_name}


@router.get("/ready", response_model=None)
def get_ready(
    database_available: Annotated[bool, Depends(database_is_available)],
) -> ReadinessResponse | JSONResponse:
    if database_available:
        return {"status": "ready", "dependencies": {"database": "available"}}

    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"status": "not_ready", "dependencies": {"database": "unavailable"}},
    )
