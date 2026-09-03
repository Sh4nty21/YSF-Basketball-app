"""Pytest fixtures.

The suite runs against in-memory SQLite so it needs no Postgres and can never
touch the real Supabase data. ``DATABASE_URL`` is forced *before* the app is
imported, because settings are read once at import time.
"""

from __future__ import annotations

import os

os.environ["DATABASE_URL"] = "sqlite://"
os.environ["MIGRATION_DATABASE_URL"] = ""
os.environ["MIN_AGE"] = "13"
os.environ["MAX_AGE"] = "22"
# Left unset deliberately: bootstrap_first_super_admin() is a no-op without
# these, and the `client` fixture below seeds its own test admin directly.
os.environ["BOOTSTRAP_ADMIN_USERNAME"] = ""
os.environ["BOOTSTRAP_ADMIN_PASSWORD"] = ""

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, event  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.config import settings  # noqa: E402
from app.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from app import models  # noqa: E402,F401  (registers tables on Base.metadata)
from app.models import Admin  # noqa: E402
from app.security import hash_password  # noqa: E402

TEST_ADMIN_USERNAME = "test-admin"
TEST_ADMIN_PASSWORD = "Test-Password-123"


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
    """TestClient wired to the throwaway SQLite session.

    Every organizer endpoint now requires a logged-in admin (see
    NEW_PROJECT_PLAN.md) — there is no more "auth off by default" mode. This
    fixture seeds one active super-admin directly (a test-only shortcut; a
    real deployment's first super-admin comes from
    ``BOOTSTRAP_ADMIN_USERNAME``/``PASSWORD``, never a direct DB insert) and
    logs in through the real ``/auth/login`` endpoint so every test gets a
    working ``Authorization`` header for free, without needing to know this
    plumbing exists. Tests that specifically exercise auth (see
    ``test_admin_auth.py``) build their own unauthenticated/second-admin
    clients instead of relying on this default.
    """

    def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        admin = Admin(
            username=TEST_ADMIN_USERNAME,
            display_name="Test Admin",
            password_hash=hash_password(TEST_ADMIN_PASSWORD),
            role="super_admin",
            is_active=True,
            must_change_password=False,
        )
        db_session.add(admin)
        db_session.commit()

        login_response = test_client.post(
            f"{settings.api_prefix}/auth/login",
            json={"username": TEST_ADMIN_USERNAME, "password": TEST_ADMIN_PASSWORD},
        )
        assert login_response.status_code == 200, login_response.text
        test_client.headers["Authorization"] = f"Bearer {login_response.json()['token']}"

        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture()
def raw_client(db_session):
    """Same throwaway DB as ``client``, but with no admin seeded and no
    ``Authorization`` header pre-set — for tests that exercise login itself,
    unauthenticated access, or a specific admin's own token."""

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
