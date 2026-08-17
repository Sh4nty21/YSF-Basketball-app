"""End-to-end API tests against the FastAPI app (SQLite-backed).

Covers the contract in spec Section 5 plus the "don't disrupt existing rosters"
requirement from Section 6.2.
"""

from __future__ import annotations

from app.config import settings

API = settings.api_prefix


# ── sessions ──────────────────────────────────────────────────────────────


def test_health_reports_ok(client):
    body = client.get("/health").json()
    assert body["status"] == "ok"
    assert body["database"] == "connected"
    assert body["auth_required"] is False


def test_create_and_fetch_session(client):
    created = client.post(
        f"{API}/sessions",
        json={"session_date": "2026-08-22", "week_label": "Week 1", "team_format": "4v4"},
    )
    assert created.status_code == 201
    body = created.json()
    assert body["status"] == "open"
    assert body["team_format"] == "4v4"
    assert body["checkin_url"].endswith(f"?session={body['id']}")

    fetched = client.get(f"{API}/sessions/{body['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["week_label"] == "Week 1"


def test_sessions_are_listed_most_recent_first(client):
    for date in ("2026-08-01", "2026-08-15", "2026-08-08"):
        client.post(f"{API}/sessions", json={"session_date": date, "team_format": "5v5"})

    dates = [row["session_date"] for row in client.get(f"{API}/sessions").json()]
    assert dates == ["2026-08-15", "2026-08-08", "2026-08-01"]


def test_bad_team_format_is_rejected(client):
    response = client.post(
        f"{API}/sessions", json={"session_date": "2026-08-22", "team_format": "2v2"}
    )
    assert response.status_code == 422


def test_patch_updates_format_and_status(client, session_id):
    response = client.patch(
        f"{API}/sessions/{session_id}", json={"team_format": "3v3", "status": "closed"}
    )
    assert response.status_code == 200
    assert response.json()["team_format"] == "3v3"
    assert response.json()["status"] == "closed"


def test_empty_patch_is_rejected(client, session_id):
    assert client.patch(f"{API}/sessions/{session_id}", json={}).status_code == 422


def test_missing_session_returns_404(client):
    assert client.get(f"{API}/sessions/9999").status_code == 404


# ── check-in ──────────────────────────────────────────────────────────────


def test_public_checkin_records_qr_source(client, session_id, check_in):
    check_in(session_id, "Miguel", 14, "pro")
    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    assert len(attendees) == 1
    assert attendees[0]["source"] == "qr"
    assert attendees[0]["team_id"] is None


def test_manual_add_records_manual_source(client, session_id):
    response = client.post(
        f"{API}/sessions/{session_id}/attendees",
        json={"name": "Anna", "age": 13, "skill_level": "beginner"},
    )
    assert response.status_code == 201
    assert response.json()["source"] == "manual"


def test_checkin_rejects_empty_name(client, session_id):
    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "   ", "age": 12, "skill_level": "pro"},
    )
    assert response.status_code == 422


def test_checkin_rejects_out_of_range_age(client, session_id):
    for age in (0, 3, 20, 120):
        response = client.post(
            f"{API}/sessions/{session_id}/checkin",
            json={"name": "Test", "age": age, "skill_level": "pro"},
        )
        assert response.status_code == 422, f"age {age} should be rejected"


def test_checkin_rejects_bad_skill_level(client, session_id):
    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Test", "age": 12, "skill_level": "expert"},
    )
    assert response.status_code == 422


def test_name_whitespace_is_normalised(client, session_id, check_in):
    check_in(session_id, "  Juan   Dela  Cruz ")
    assert client.get(f"{API}/sessions/{session_id}/attendees").json()[0]["name"] == (
        "Juan Dela Cruz"
    )


def test_checkin_blocked_on_closed_session(client, session_id):
    client.patch(f"{API}/sessions/{session_id}", json={"status": "closed"})
    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Late", "age": 12, "skill_level": "pro"},
    )
    assert response.status_code == 409

    # ...but the organizer can still add manually.
    assert (
        client.post(
            f"{API}/sessions/{session_id}/attendees",
            json={"name": "Late", "age": 12, "skill_level": "pro"},
        ).status_code
        == 201
    )


def test_checkin_to_unknown_session_returns_404(client):
    response = client.post(
        f"{API}/sessions/424242/checkin",
        json={"name": "Ghost", "age": 12, "skill_level": "pro"},
    )
    assert response.status_code == 404


# ── teams ─────────────────────────────────────────────────────────────────


def _fill(check_in, session_id, count: int, skill: str = "beginner") -> list[int]:
    return [check_in(session_id, f"{skill.title()}{i}", 12, skill) for i in range(count)]


def test_generate_without_attendees_returns_409(client, session_id):
    response = client.post(f"{API}/sessions/{session_id}/teams/generate")
    assert response.status_code == 409


def test_generate_builds_teams_and_names_them(client, session_id, check_in):
    _fill(check_in, session_id, 10)
    body = client.post(f"{API}/sessions/{session_id}/teams/generate").json()

    assert [team["team_name"] for team in body["teams"]] == ["Team A", "Team B"]
    assert body["team_format"] == "5v5"
    assert body["unassigned"] == []
    assert all(m["added_via"] == "generate" for t in body["teams"] for m in t["members"])


def test_generate_is_idempotent_in_shape_and_does_not_duplicate_rows(client, session_id, check_in):
    _fill(check_in, session_id, 8)
    first = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    second = client.post(f"{API}/sessions/{session_id}/teams/generate").json()

    assert len(first["teams"]) == len(second["teams"]) == 2
    placed = [m["attendee_id"] for t in second["teams"] for m in t["members"]]
    assert len(placed) == 8 and len(set(placed)) == 8


def test_attendee_list_shows_team_after_generate(client, session_id, check_in):
    _fill(check_in, session_id, 4)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    assert all(a["team_name"] == "Team A" for a in attendees)


def test_late_arrival_appears_as_unassigned(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    late_id = check_in(session_id, "Late Larry", 15, "pro")

    body = client.get(f"{API}/sessions/{session_id}/teams").json()
    assert [a["id"] for a in body["unassigned"]] == [late_id]

    picker = client.get(f"{API}/sessions/{session_id}/attendees/unassigned").json()
    assert [a["id"] for a in picker] == [late_id]


def test_add_player_does_not_disturb_existing_rosters(client, session_id, check_in):
    """The Section 6.2 guarantee, verified explicitly."""
    _fill(check_in, session_id, 10)
    before = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    snapshot = {
        team["team_name"]: sorted(m["attendee_id"] for m in team["members"])
        for team in before["teams"]
    }

    late_id = check_in(session_id, "Late Larry", 15, "pro")
    after = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": late_id}
    ).json()

    for team in after["teams"]:
        original = snapshot[team["team_name"]]
        now = sorted(m["attendee_id"] for m in team["members"])
        assert set(original).issubset(set(now)), "an existing player was moved"
        assert set(now) - set(original) in ({late_id}, set())

    all_now = [m["attendee_id"] for t in after["teams"] for m in t["members"]]
    assert late_id in all_now
    assert after["unassigned"] == []


def test_add_player_chooses_the_team_short_on_that_skill(client, session_id, check_in):
    # Two teams, hand-built via generate then inspected: add a pro and confirm
    # it lands on whichever team has fewer pros.
    _fill(check_in, session_id, 3, "pro")
    _fill(check_in, session_id, 5, "beginner")
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    pro_counts = {
        team["team_name"]: sum(1 for m in team["members"] if m["skill_level"] == "pro")
        for team in generated["teams"]
    }
    expected_team = min(pro_counts, key=lambda name: pro_counts[name])

    late_id = check_in(session_id, "Pro Late", 16, "pro")
    after = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": late_id}
    ).json()

    landed = next(
        team["team_name"]
        for team in after["teams"]
        if any(m["attendee_id"] == late_id for m in team["members"])
    )
    assert landed == expected_team
    assert next(
        m["added_via"]
        for team in after["teams"]
        for m in team["members"]
        if m["attendee_id"] == late_id
    ) == "manual-add"


def test_add_player_twice_returns_409(client, session_id, check_in):
    ids = _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    response = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": ids[0]}
    )
    assert response.status_code == 409


def test_add_player_before_generate_returns_409(client, session_id, check_in):
    late_id = check_in(session_id, "Solo", 12, "pro")
    response = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": late_id}
    )
    assert response.status_code == 409


def test_add_player_from_another_session_returns_404(client, session_id, check_in):
    other = client.post(
        f"{API}/sessions", json={"session_date": "2026-09-01", "team_format": "5v5"}
    ).json()["id"]
    outsider = check_in(other, "Outsider", 12, "pro")

    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    response = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": outsider}
    )
    assert response.status_code == 404


def test_regenerate_wipes_manual_adds(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    late_id = check_in(session_id, "Late", 15, "pro")
    client.post(f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": late_id})

    after = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    assert all(
        m["added_via"] == "generate" for team in after["teams"] for m in team["members"]
    )
    placed = [m["attendee_id"] for team in after["teams"] for m in team["members"]]
    assert sorted(placed) == sorted(placed) and len(placed) == 6


# ── stats ─────────────────────────────────────────────────────────────────


def test_stats_breakdown(client, session_id, check_in):
    check_in(session_id, "A", 12, "pro")
    check_in(session_id, "B", 14, "pro")
    check_in(session_id, "C", 16, "intermediate")
    client.post(
        f"{API}/sessions/{session_id}/attendees",
        json={"name": "D", "age": 10, "skill_level": "beginner"},
    )
    client.post(f"{API}/sessions/{session_id}/teams/generate")

    stats = client.get(f"{API}/sessions/{session_id}/stats").json()
    assert stats["total_attendance"] == 4
    assert stats["skill_breakdown"] == {"beginner": 1, "intermediate": 1, "pro": 2}
    assert stats["source_breakdown"] == {"qr": 3, "manual": 1}
    assert stats["team_count"] == 1
    assert stats["assigned_count"] == 4
    assert stats["unassigned_count"] == 0
    assert stats["average_age"] == 13.0


def test_stats_on_empty_session(client, session_id):
    stats = client.get(f"{API}/sessions/{session_id}/stats").json()
    assert stats["total_attendance"] == 0
    assert stats["average_age"] is None
    assert stats["skill_breakdown"] == {"beginner": 0, "intermediate": 0, "pro": 0}


# ── session deletion cascades ─────────────────────────────────────────────


def test_session_counts_are_reported(client, session_id, check_in):
    _fill(check_in, session_id, 6)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    body = client.get(f"{API}/sessions/{session_id}").json()
    assert body["attendee_count"] == 6
    assert body["team_count"] == 2
