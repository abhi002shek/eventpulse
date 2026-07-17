import logging
import time
from collections.abc import Callable

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker

from app.configuration.settings import get_settings
from app.metrics import observe_database_readiness

logger = logging.getLogger(__name__)

settings = get_settings()
engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, class_=Session, expire_on_commit=False)


def check_database_connection(
    session_factory: Callable[[], Session] = SessionLocal,
) -> bool:
    start = time.perf_counter()
    try:
        with session_factory() as session:
            session.execute(text("SELECT 1"))
    except SQLAlchemyError:
        observe_database_readiness(time.perf_counter() - start, succeeded=False)
        logger.warning("Database readiness check failed")
        return False

    observe_database_readiness(time.perf_counter() - start, succeeded=True)
    return True
