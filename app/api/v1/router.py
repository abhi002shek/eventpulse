from fastapi import APIRouter

from app.bookings.routes import router as bookings_router
from app.events.routes import router as events_router

router = APIRouter()
router.include_router(events_router)
router.include_router(bookings_router)
