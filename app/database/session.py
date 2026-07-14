import logging
from collections.abc import Callable

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker

from app.configuration.settings import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()
engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, class_=Session, expire_on_commit=False)


def check_database_connection(
    session_factory: Callable[[], Session] = SessionLocal,
) -> bool:
    try:
        with session_factory() as session:
            session.execute(text("SELECT 1"))
    except SQLAlchemyError:
        logger.warning("Database readiness check failed")
        return False

    return True
