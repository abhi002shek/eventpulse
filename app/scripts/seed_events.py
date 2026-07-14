import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.exc import SQLAlchemyError

from app.database.session import SessionLocal
from app.events.models import Event
from app.events.repository import EventRepository
from app.logging_config import configure_logging

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class DemoEvent:
    public_id: UUID
    name: str
    description: str
    starts_at: datetime
    venue: str
    total_capacity: int
    available_capacity: int


DEMO_EVENTS = (
    DemoEvent(
        public_id=UUID("11111111-1111-4111-8111-111111111111"),
        name="EventPulse Tech Summit",
        description="A practical conference for backend, platform, and DevOps engineers.",
        starts_at=datetime(2026, 9, 10, 9, 0, tzinfo=UTC),
        venue="Bengaluru Convention Centre",
        total_capacity=300,
        available_capacity=300,
    ),
    DemoEvent(
        public_id=UUID("22222222-2222-4222-8222-222222222222"),
        name="Midnight Frequency Live",
        description="An evening live music showcase with independent electronic artists.",
        starts_at=datetime(2026, 9, 18, 19, 30, tzinfo=UTC),
        venue="Mumbai Live Hall",
        total_capacity=800,
        available_capacity=800,
    ),
    DemoEvent(
        public_id=UUID("33333333-3333-4333-8333-333333333333"),
        name="South Asia Esports Arena",
        description="A regional esports tournament featuring team finals and creator matches.",
        starts_at=datetime(2026, 10, 3, 12, 0, tzinfo=UTC),
        venue="Hyderabad Digital Arena",
        total_capacity=1200,
        available_capacity=1200,
    ),
    DemoEvent(
        public_id=UUID("44444444-4444-4444-8444-444444444444"),
        name="Cloud Engineering Workshop",
        description="A hands-on workshop focused on containers, CI/CD, and secure operations.",
        starts_at=datetime(2026, 10, 14, 10, 0, tzinfo=UTC),
        venue="Pune Engineering Hub",
        total_capacity=60,
        available_capacity=60,
    ),
    DemoEvent(
        public_id=UUID("55555555-5555-4555-8555-555555555555"),
        name="Startup Demo Day",
        description="Founders present early products to engineers, operators, and investors.",
        starts_at=datetime(2026, 11, 5, 14, 0, tzinfo=UTC),
        venue="Delhi Innovation Studio",
        total_capacity=180,
        available_capacity=180,
    ),
)


def seed_events() -> tuple[int, int]:
    inserted = 0
    already_existed = 0

    try:
        with SessionLocal.begin() as session:
            repository = EventRepository(session)
            demo_ids = {event.public_id for event in DEMO_EVENTS}
            existing_ids = repository.get_existing_public_ids(demo_ids)

            for demo_event in DEMO_EVENTS:
                if demo_event.public_id in existing_ids:
                    already_existed += 1
                    continue

                repository.add_event(
                    Event(
                        public_id=demo_event.public_id,
                        name=demo_event.name,
                        description=demo_event.description,
                        starts_at=demo_event.starts_at,
                        venue=demo_event.venue,
                        total_capacity=demo_event.total_capacity,
                        available_capacity=demo_event.available_capacity,
                    )
                )
                inserted += 1
    except SQLAlchemyError:
        logger.warning("Failed to seed demonstration events; transaction rolled back")
        raise

    return inserted, already_existed


def main() -> None:
    configure_logging("INFO")
    inserted, already_existed = seed_events()
    print(f"Demo events inserted: {inserted}; already existed: {already_existed}")


if __name__ == "__main__":
    main()
