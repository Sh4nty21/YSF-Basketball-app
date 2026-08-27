"""Pytest fixtures.

The suite runs against in-memory SQLite so it needs no Postgres and can never
touch the real Supabase data. ``DATABASE_URL`` is forced *before* the app is
imported, because settings are read once at import time.
"""

from __future__ import annotations

import os

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["MIGRATION_DATABASE_URL"] = ""
os.environ["ORGANIZER_API_KEY"] = ""
os.environ["MIN_AGE"] = "13"
os.environ["MAX_AGE"] = "22"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, event  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.config import settings  # noqa: E402
from app.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app import models  # noqa: E402,F401  (registers tables on Base.metadata)


@pytest.fixture()
def db_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,  # one shared connection == one shared in-memory DB
        future=True,
    )

    # SQLite ignores foreign keys (and therefore ON DELETE CASCADE) unless asked.
    @event.listens_for(engine, "connect")
    def _enable_fk(dbapi_connection, _record):  # pragma: no cover - driver hook
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture()
def db_session(db_engine):
    factory = sessionmaker(bind=db_engine, autoflush=False, autocommit=False, future=True)
    session = factory()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def client(db_session):
    """TestClient wired to the throwaway SQLite session."""

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture()
def session_id(client) -> int:
    response = client.post(
        f"{settings.api_prefix}/sessions",
        json={"session_date": "2026-08-22", "week_label": "Week 1", "team_format": "5v5"},
    )
    assert response.status_code == 201, response.text
    return response.json()["id"]


@pytest.fixture()
def check_in(client):
    """Helper: check a participant in via the public endpoint, return their id.

    Each call defaults to a fresh, unique ``device_id`` so existing tests are
    never affected by the per-device check-in cap. Pass ``device_id``
    explicitly to test the cap itself.
    """
    _counter = {"n": 0}

    def _check_in(
        session_id: int,
        name: str,
        age: int = 14,
        skill: str = "beginner",
        device_id: str | None = None,
    ) -> int:
        _counter["n"] += 1
        response = client.post(
            f"{settings.api_prefix}/sessions/{session_id}/checkin",
            json={
                "name": name,
                "age": age,
                "skill_level": skill,
                "device_id": device_id or f"test-device-{_counter['n']}",
            },
        )
        assert response.status_code == 201, response.text
        return response.json()["attendee_id"]

    return _check_in
