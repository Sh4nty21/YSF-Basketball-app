"""Database engine, session factory and the FastAPI dependency.

Responsibility: connection plumbing only. No queries and no business rules —
those live in ``app.repositories`` and ``app.services`` respectively.
"""

from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings


class Base(DeclarativeBase):
    """Declarative base shared by every ORM model."""


def _engine_kwargs() -> dict:
    if settings.is_sqlite:
        # SQLite is only used for tests and first-boot exploration.
        return {"connect_args": {"check_same_thread": False}}

    # Supabase's transaction pooler closes idle connections aggressively and
    # does not support server-side prepared statements, so:
    #   * pool_pre_ping  -> discard dead connections instead of erroring
    #   * pool_recycle   -> refresh sockets before the pooler drops them
    #   * prepare_threshold=None -> psycopg never prepares statements
    return {
        "pool_pre_ping": True,
        "pool_recycle": 300,
        "pool_size": 5,
        "max_overflow": 5,
        "connect_args": {"prepare_threshold": None},
    }


engine = create_engine(settings.sqlalchemy_url, future=True, **_engine_kwargs())

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


def get_db() -> Iterator[Session]:
    """FastAPI dependency yielding a request-scoped database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
