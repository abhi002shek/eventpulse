from collections.abc import Generator

from sqlalchemy.orm import Session

from app.database.session import SessionLocal, check_database_connection


def get_db_session() -> Generator[Session, None, None]:
    with SessionLocal() as session:
        yield session


def database_is_available() -> bool:
    return check_database_connection()
