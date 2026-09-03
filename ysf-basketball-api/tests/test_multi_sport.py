"""End-to-end tests for the volleyball/badminton endpoints — session
creation, sport-conditional check-in validation, and `/teams/generate`
actually dispatching to the right algorithm.
"""

from __future__ import annotations

from app.config import settings

API = settings.api_prefix


def _create_session(client, sport: str, **extra) -> int:
    payload = {"session_date": "2026-09-10", "sport": sport, **extra}
    response = client.post(f"{API}/sessions", json=payload)
    assert response.status_code == 201, response.text
    return response.json()["id"]


def _checkin(client, session_id: int, device_id: str, **fields) -> dict:
    payload = {"name": "Player", "age": 16, "device_id": device_id, **fields}
    response = client.post(f"{API}/sessions/{session_id}/checkin", json=payload)
    assert response.status_code == 201, response.text
    return response.json()


# ── session creation ────────────────────────────────────────────────────


def test_create_volleyball_session_without_team_format(client):
    session_id = _create_session(client, "volleyball")
    body = client.get(f"{API}/sessions/{session_id}").json()
    assert body["sport"] == "volleyball"
    assert body["team_format"] is None


def test_badminton_session_requires_a_mode(client):
    response = client.post(
        f"{API}/sessions", json={"session_date": "2026-09-10", "sport": "badminton"}
    )
    assert response.status_code == 422


def test_create_badminton_doubles_session(client):
    session_id = _create_session(client, "badminton", badminton_mode="doubles")
    body = client.get(f"{API}/sessions/{session_id}").json()
    assert body["badminton_mode"] == "doubles"


# ── sport-conditional check-in validation ───────────────────────────────


def test_volleyball_checkin_requires_position_not_skill(client):
    session_id = _create_session(client, "volleyball")

    missing_position = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Pat", "age": 16, "device_id": "d1", "skill_level": "beginner"},
    )
    assert missing_position.status_code == 422

    with_position = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Pat", "age": 16, "device_id": "d1", "position": "setter"},
    )
    assert with_position.status_code == 201


def test_badminton_checkin_requires_skill_not_position(client):
    session_id = _create_session(client, "badminton", badminton_mode="singles")

    missing_skill = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Pat", "age": 16, "device_id": "d1", "position": "setter"},
    )
    assert missing_skill.status_code == 422

    with_skill = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Pat", "age": 16, "device_id": "d1", "skill_level": "beginner"},
    )
    assert with_skill.status_code == 201


# ── generate dispatches to the right algorithm ──────────────────────────


def test_generate_volleyball_teams_end_to_end(client):
    session_id = _create_session(client, "volleyball")
    positions = (
        ["outside_hitter"] * 2 + ["middle_blocker"] * 2 + ["setter"] * 1 + ["opposite"] * 1
    )
    for i, position in enumerate(positions):
        _checkin(client, session_id, device_id=f"d{i}", position=position)

    response = client.post(f"{API}/sessions/{session_id}/teams/generate")
    assert response.status_code == 200, response.text
    body = response.json()
    assert len(body["teams"]) == 1
    assert len(body["teams"][0]["members"]) == 6


def test_generate_badminton_doubles_end_to_end(client):
    session_id = _create_session(client, "badminton", badminton_mode="doubles")
    for i in range(4):
        _checkin(client, session_id, device_id=f"d{i}", skill_level="beginner")

    response = client.post(f"{API}/sessions/{session_id}/teams/generate")
    assert response.status_code == 200, response.text
    body = response.json()
    assert len(body["teams"]) == 2
    for team in body["teams"]:
        assert len(team["members"]) == 2


def test_generate_with_no_checkins_is_a_conflict(client):
    session_id = _create_session(client, "volleyball")
    response = client.post(f"{API}/sessions/{session_id}/teams/generate")
    assert response.status_code == 409


def test_checkin_info_is_public_and_reveals_only_sport_and_status(client, raw_client):
    session_id = _create_session(client, "volleyball")
    response = raw_client.get(f"{API}/sessions/{session_id}/checkin-info")
    assert response.status_code == 200
    assert response.json() == {"sport": "volleyball", "status": "open"}


def test_add_player_not_available_yet_for_badminton(client):
    session_id = _create_session(client, "badminton", badminton_mode="doubles")
    attendee = _checkin(client, session_id, device_id="d1", skill_level="beginner")

    response = client.post(
        f"{API}/sessions/{session_id}/teams/add-player",
        json={"attendee_id": attendee["attendee_id"]},
    )
    assert response.status_code == 409


def test_volleyball_late_checkin_autofills_the_right_position_and_is_marked_late(client):
    # A full team (2 OH, 2 MB, 1 setter, 1 opposite), generated first.
    positions = (
        ["outside_hitter"] * 2 + ["middle_blocker"] * 2 + ["setter"] * 1 + ["opposite"] * 1
    )
    session_id = _create_session(client, "volleyball")
    for i, position in enumerate(positions):
        _checkin(client, session_id, device_id=f"d{i}", position=position)
    client.post(f"{API}/sessions/{session_id}/teams/generate")

    # The initial roster is exactly one full team's worth (quota 1/1 setters
    # already), so a late setter can't slot into it — auto-placed onto a
    # brand-new team instead, immediately, no manual step needed (same
    # "late registration" behaviour as basketball).
    late = _checkin(client, session_id, device_id="d-late", position="setter")

    teams = client.get(f"{API}/sessions/{session_id}/teams").json()
    assert teams["unassigned"] == []
    assert len(teams["teams"]) == 2
    all_members = [m for team in teams["teams"] for m in team["members"]]
    late_member = next(m for m in all_members if m["attendee_id"] == late["attendee_id"])
    assert late_member["added_via"] == "manual-add"
    assert late_member["position"] == "setter"

    # A second late setter: the original team is still full, and the new
    # team from the first late setter is now also full for setter (1/1) —
    # so this one starts yet another new team.
    second_late = _checkin(client, session_id, device_id="d-late-2", position="setter")
    teams_after = client.get(f"{API}/sessions/{session_id}/teams").json()
    assert len(teams_after["teams"]) == 3
    newest_team = teams_after["teams"][2]
    assert any(m["attendee_id"] == second_late["attendee_id"] for m in newest_team["members"])


def test_volleyball_add_player_fallback_fills_the_matching_position(client):
    positions = (
        ["outside_hitter"] * 2 + ["middle_blocker"] * 2 + ["setter"] * 1 + ["opposite"] * 1
    )
    session_id = _create_session(client, "volleyball")
    for i, position in enumerate(positions):
        _checkin(client, session_id, device_id=f"d{i}", position=position)
    client.post(f"{API}/sessions/{session_id}/teams/generate")

    # Manually add an opposite via the organizer manual-add endpoint, which
    # (unlike public check-in) never auto-places — then use the explicit
    # add-player fallback.
    manual = client.post(
        f"{API}/sessions/{session_id}/attendees",
        json={"name": "Late Opp", "age": 16, "position": "opposite"},
    )
    assert manual.status_code == 201
    # attendees.py DOES auto-place volleyball too, so this one is already on
    # a team — prove the fallback correctly rejects a double-placement.
    fallback = client.post(
        f"{API}/sessions/{session_id}/teams/add-player",
        json={"attendee_id": manual.json()["id"]},
    )
    assert fallback.status_code == 409
    assert "already on a team" in fallback.json()["detail"]
