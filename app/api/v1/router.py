from fastapi import APIRouter

from app.events.routes import router as events_router

router = APIRouter()
router.include_router(events_router)
