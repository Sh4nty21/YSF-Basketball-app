"""The optional organizer key (``ORGANIZER_API_KEY``).

Off by default per spec Section 2; these tests prove that switching it on locks
organizer endpoints while leaving the public check-in endpoint reachable.
"""

from __future__ import annotations

import pytest

from app.config import settings
from app.security import HEADER_NAME

API = settings.api_prefix
KEY = "test-organizer-key"


@pytest.fixture()
def locked(monkeypatch):
    monkeypatch.setattr(settings, "organizer_api_key", KEY)
    assert settings.auth_enabled
    yield


def test_organizer_endpoint_requires_key(client, locked):
    assert client.get(f"{API}/sessions").status_code == 401


def test_wrong_key_is_rejected(client, locked):
    response = client.get(f"{API}/sessions", headers={HEADER_NAME: "nope"})
    assert response.status_code == 401


def test_correct_key_is_accepted(client, locked):
    response = client.get(f"{API}/sessions", headers={HEADER_NAME: KEY})
    assert response.status_code == 200


def test_public_checkin_never_requires_a_key(client, locked):
    created = client.post(
        f"{API}/sessions",
        headers={HEADER_NAME: KEY},
        json={"session_date": "2026-08-22", "team_format": "5v5"},
    )
    session_id = created.json()["id"]

    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={
            "name": "Public Pat",
            "age": 14,
            "skill_level": "beginner",
            "device_id": "test-device",
        },
    )
    assert response.status_code == 201


def test_auth_is_off_by_default(client):
    assert settings.auth_enabled is False
    assert client.get(f"{API}/sessions").status_code == 200
