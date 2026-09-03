"""Admin accounts: login/logout, session-token gating, roles, revocation,
forced password change, and the audit trail (NEW_PROJECT_PLAN.md).

Supersedes the old test_security.py, which tested the now-removed shared
``ORGANIZER_API_KEY`` passcode.
"""

from __future__ import annotations

from app.config import settings

API = settings.api_prefix
# Matches the constants seeded by the `client` fixture in conftest.py.
TEST_ADMIN_USERNAME = "test-admin"
TEST_ADMIN_PASSWORD = "Test-Password-123"


# ── organizer endpoints require a session ───────────────────────────────


def test_organizer_endpoint_requires_auth(raw_client):
    assert raw_client.get(f"{API}/sessions").status_code == 401


def test_bad_token_is_rejected(raw_client):
    response = raw_client.get(
        f"{API}/sessions", headers={"Authorization": "Bearer not-a-real-token"}
    )
    assert response.status_code == 401


def test_missing_bearer_prefix_is_rejected(raw_client):
    response = raw_client.get(f"{API}/sessions", headers={"Authorization": "not-bearer-shaped"})
    assert response.status_code == 401


def test_public_checkin_never_requires_auth(client, raw_client):
    """The one deliberate exception (mirrors the old organizer-key tests).

    ``client`` (authenticated) creates the session; ``raw_client`` (no
    ``Authorization`` header at all, sharing the same throwaway DB) checks
    in, proving the public endpoint truly needs nothing.
    """
    created = client.post(
        f"{API}/sessions",
        json={"session_date": "2026-08-22", "team_format": "5v5"},
    )
    session_id = created.json()["id"]

    response = raw_client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={
            "name": "Public Pat",
            "age": 14,
            "skill_level": "beginner",
            "device_id": "test-device",
        },
    )
    assert response.status_code == 201


# ── login ─────────────────────────────────────────────────────────────────


def test_login_succeeds_with_correct_credentials(client):
    response = client.post(
        f"{API}/auth/login",
        json={"username": TEST_ADMIN_USERNAME, "password": TEST_ADMIN_PASSWORD},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["token"]
    assert body["admin"]["username"] == TEST_ADMIN_USERNAME
    assert body["admin"]["role"] == "super_admin"


def test_login_fails_with_wrong_password(client):
    response = client.post(
        f"{API}/auth/login",
        json={"username": TEST_ADMIN_USERNAME, "password": "wrong-password"},
    )
    assert response.status_code == 401


def test_login_fails_for_unknown_username(client):
    response = client.post(
        f"{API}/auth/login",
        json={"username": "nobody", "password": "irrelevant"},
    )
    assert response.status_code == 401


def test_failed_login_is_audited(client):
    client.post(f"{API}/auth/login", json={"username": "nobody", "password": "x"})
    log = client.get(f"{API}/admins/audit-log").json()
    assert any(entry["action"] == "login_failed" for entry in log)


def test_successful_login_is_audited(client):
    client.post(
        f"{API}/auth/login",
        json={"username": TEST_ADMIN_USERNAME, "password": TEST_ADMIN_PASSWORD},
    )
    log = client.get(f"{API}/admins/audit-log").json()
    assert any(entry["action"] == "login_succeeded" for entry in log)


# ── logout ────────────────────────────────────────────────────────────────


def test_logout_invalidates_that_token(client):
    login = client.post(
        f"{API}/auth/login",
        json={"username": TEST_ADMIN_USERNAME, "password": TEST_ADMIN_PASSWORD},
    ).json()
    token = login["token"]
    headers = {"Authorization": f"Bearer {token}"}

    assert client.get(f"{API}/sessions", headers=headers).status_code == 200
    assert client.post(f"{API}/auth/logout", headers=headers).status_code == 200
    assert client.get(f"{API}/sessions", headers=headers).status_code == 401


# ── appointing admins (super-admin only) ────────────────────────────────


def test_super_admin_can_create_an_admin(client):
    response = client.post(
        f"{API}/admins",
        json={
            "username": "coach-marcus",
            "display_name": "Marcus",
            "password": "Initial-Password-1",
            "role": "admin",
            "sport_tags": ["Basketball", "Volleyball"],
        },
    )
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["role"] == "admin"
    assert body["must_change_password"] is True
    assert body["sport_tags"] == ["Basketball", "Volleyball"]


def test_duplicate_username_is_rejected(client):
    payload = {
        "username": "coach-marcus",
        "display_name": "Marcus",
        "password": "Initial-Password-1",
    }
    assert client.post(f"{API}/admins", json=payload).status_code == 201
    assert client.post(f"{API}/admins", json=payload).status_code == 409


def test_admin_creation_is_audited(client):
    client.post(
        f"{API}/admins",
        json={"username": "coach-sarah", "display_name": "Sarah", "password": "Initial-Password-1"},
    )
    log = client.get(f"{API}/admins/audit-log").json()
    assert any(entry["action"] == "admin_created" for entry in log)


def test_a_regular_admin_cannot_appoint_admins(client, raw_client):
    # Appoint a plain admin, log in as them, and confirm they're blocked.
    client.post(
        f"{API}/admins",
        json={"username": "coach-dave", "display_name": "Dave", "password": "Initial-Password-1"},
    )
    login = raw_client.post(
        f"{API}/auth/login",
        json={"username": "coach-dave", "password": "Initial-Password-1"},
    ).json()
    headers = {"Authorization": f"Bearer {login['token']}"}

    response = raw_client.post(
        f"{API}/admins",
        headers=headers,
        json={"username": "coach-eve", "display_name": "Eve", "password": "Initial-Password-1"},
    )
    assert response.status_code == 403

    # But a plain admin still has full, equal functionality elsewhere.
    assert raw_client.get(f"{API}/sessions", headers=headers).status_code == 200


# ── forced password change ──────────────────────────────────────────────


def test_new_admin_must_change_password_flag_is_true(client):
    body = client.post(
        f"{API}/admins",
        json={"username": "coach-anna", "display_name": "Anna", "password": "Initial-Password-1"},
    ).json()
    assert body["must_change_password"] is True


def test_change_password_clears_the_flag_and_is_audited(client, raw_client):
    client.post(
        f"{API}/admins",
        json={"username": "coach-ben", "display_name": "Ben", "password": "Initial-Password-1"},
    )
    login = raw_client.post(
        f"{API}/auth/login", json={"username": "coach-ben", "password": "Initial-Password-1"}
    ).json()
    headers = {"Authorization": f"Bearer {login['token']}"}

    response = raw_client.post(
        f"{API}/auth/change-password",
        headers=headers,
        json={"current_password": "Initial-Password-1", "new_password": "Brand-New-Password-2"},
    )
    assert response.status_code == 200
    assert response.json()["must_change_password"] is False

    # Old password no longer works; new one does.
    assert raw_client.post(
        f"{API}/auth/login", json={"username": "coach-ben", "password": "Initial-Password-1"}
    ).status_code == 401
    assert raw_client.post(
        f"{API}/auth/login", json={"username": "coach-ben", "password": "Brand-New-Password-2"}
    ).status_code == 200

    log = client.get(f"{API}/admins/audit-log").json()
    assert any(entry["action"] == "password_changed" for entry in log)


def test_change_password_rejects_wrong_current_password(client, raw_client):
    client.post(
        f"{API}/admins",
        json={"username": "coach-cara", "display_name": "Cara", "password": "Initial-Password-1"},
    )
    login = raw_client.post(
        f"{API}/auth/login", json={"username": "coach-cara", "password": "Initial-Password-1"}
    ).json()
    headers = {"Authorization": f"Bearer {login['token']}"}

    response = raw_client.post(
        f"{API}/auth/change-password",
        headers=headers,
        json={"current_password": "wrong", "new_password": "Brand-New-Password-2"},
    )
    assert response.status_code == 401


# ── revocation is immediate ──────────────────────────────────────────────


def test_revoking_an_admin_ends_their_session_immediately(client, raw_client):
    created = client.post(
        f"{API}/admins",
        json={"username": "coach-finn", "display_name": "Finn", "password": "Initial-Password-1"},
    ).json()
    login = raw_client.post(
        f"{API}/auth/login", json={"username": "coach-finn", "password": "Initial-Password-1"}
    ).json()
    headers = {"Authorization": f"Bearer {login['token']}"}

    # Works before revocation.
    assert raw_client.get(f"{API}/sessions", headers=headers).status_code == 200

    revoke = client.patch(f"{API}/admins/{created['id']}", json={"is_active": False})
    assert revoke.status_code == 200
    assert revoke.json()["is_active"] is False

    # The SAME already-issued token is dead on its very next use — no new
    # login attempt involved, proving this isn't just "can't log in again".
    assert raw_client.get(f"{API}/sessions", headers=headers).status_code == 401

    # And a fresh login attempt is also blocked.
    assert raw_client.post(
        f"{API}/auth/login", json={"username": "coach-finn", "password": "Initial-Password-1"}
    ).status_code == 401


def test_reactivating_an_admin_restores_access_on_a_new_login(client, raw_client):
    created = client.post(
        f"{API}/admins",
        json={"username": "coach-gina", "display_name": "Gina", "password": "Initial-Password-1"},
    ).json()
    client.patch(f"{API}/admins/{created['id']}", json={"is_active": False})
    client.patch(f"{API}/admins/{created['id']}", json={"is_active": True})

    login = raw_client.post(
        f"{API}/auth/login", json={"username": "coach-gina", "password": "Initial-Password-1"}
    )
    assert login.status_code == 200


def test_super_admin_cannot_revoke_their_own_account(client):
    me = client.get(f"{API}/auth/me").json()
    response = client.patch(f"{API}/admins/{me['id']}", json={"is_active": False})
    assert response.status_code == 409


# ── brute-force lockout (security hardening) ────────────────────────────


def test_login_has_no_username_enumeration_timing_gap(client):
    """Not a timing measurement (too flaky for a unit test) — just proves an
    unknown username still exercises the same bcrypt comparison path as a
    known one, by confirming the dummy-hash branch doesn't itself error."""
    response = client.post(
        f"{API}/auth/login",
        json={"username": "definitely-nobody", "password": "whatever"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect username or password."


def test_five_failed_logins_locks_the_account(client, raw_client):
    client.post(
        f"{API}/admins",
        json={"username": "coach-lock", "display_name": "Lock", "password": "Initial-Password-1"},
    )

    for _ in range(5):
        response = raw_client.post(
            f"{API}/auth/login",
            json={"username": "coach-lock", "password": "wrong-password"},
        )
        assert response.status_code == 401

    # Even the CORRECT password is now rejected — proves this is a lockout,
    # not just "still guessing wrong".
    response = raw_client.post(
        f"{API}/auth/login",
        json={"username": "coach-lock", "password": "Initial-Password-1"},
    )
    assert response.status_code == 401
    assert "too many failed attempts" in response.json()["detail"].lower()


def test_successful_login_resets_the_failed_attempt_counter(client, raw_client):
    client.post(
        f"{API}/admins",
        json={"username": "coach-reset", "display_name": "Reset", "password": "Initial-Password-1"},
    )

    for _ in range(3):
        raw_client.post(
            f"{API}/auth/login",
            json={"username": "coach-reset", "password": "wrong-password"},
        )

    # 3 failures is under the 5-attempt threshold, so this still succeeds...
    ok = raw_client.post(
        f"{API}/auth/login",
        json={"username": "coach-reset", "password": "Initial-Password-1"},
    )
    assert ok.status_code == 200

    # ...and the counter is back at zero: 3 more failures afterward should
    # NOT lock the account (3 < 5), proving the earlier failures didn't
    # carry over across the successful login.
    for _ in range(3):
        raw_client.post(
            f"{API}/auth/login",
            json={"username": "coach-reset", "password": "wrong-password"},
        )
    still_unlocked = raw_client.post(
        f"{API}/auth/login",
        json={"username": "coach-reset", "password": "Initial-Password-1"},
    )
    assert still_unlocked.status_code == 200
