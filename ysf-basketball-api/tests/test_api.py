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
    # Every organizer endpoint requires a logged-in admin now — there is no
    # more "auth off by default" mode (NEW_PROJECT_PLAN.md).
    assert body["auth_required"] is True


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
    check_in(session_id, "Miguel", 14, "intermediate")
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
        json={"name": "   ", "age": 12, "skill_level": "intermediate"},
    )
    assert response.status_code == 422


def test_checkin_rejects_out_of_range_age(client, session_id):
    for age in (0, 3, 12, 23, 120):
        response = client.post(
            f"{API}/sessions/{session_id}/checkin",
            json={"name": "Test", "age": age, "skill_level": "intermediate"},
        )
        assert response.status_code == 422, f"age {age} should be rejected"


def test_checkin_rejects_bad_skill_level(client, session_id):
    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Test", "age": 14, "skill_level": "expert"},
    )
    assert response.status_code == 422


def test_checkin_rejects_retired_pro_skill_level(client, session_id):
    """'pro' was retired in favour of two tiers: beginner / intermediate."""
    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Test", "age": 14, "skill_level": "pro", "device_id": "d1"},
    )
    assert response.status_code == 422


def test_checkin_requires_device_id(client, session_id):
    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "No Device", "age": 14, "skill_level": "beginner"},
    )
    assert response.status_code == 400


def test_checkin_device_cap_blocks_after_five(client, session_id):
    for i in range(5):
        response = client.post(
            f"{API}/sessions/{session_id}/checkin",
            json={
                "name": f"Sibling{i}",
                "age": 14,
                "skill_level": "beginner",
                "device_id": "shared-phone",
            },
        )
        assert response.status_code == 201, response.text

    sixth = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={
            "name": "SixthSibling",
            "age": 14,
            "skill_level": "beginner",
            "device_id": "shared-phone",
        },
    )
    assert sixth.status_code == 429

    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    assert len(attendees) == 5


def test_checkin_device_cap_is_per_session(client, session_id):
    other = client.post(
        f"{API}/sessions", json={"session_date": "2026-09-01", "team_format": "5v5"}
    ).json()["id"]

    for i in range(5):
        client.post(
            f"{API}/sessions/{session_id}/checkin",
            json={
                "name": f"A{i}",
                "age": 14,
                "skill_level": "beginner",
                "device_id": "shared-phone",
            },
        )

    # Same device, a different session's cap has not been touched yet.
    response = client.post(
        f"{API}/sessions/{other}/checkin",
        json={
            "name": "First in new session",
            "age": 14,
            "skill_level": "beginner",
            "device_id": "shared-phone",
        },
    )
    assert response.status_code == 201


def test_checkin_device_cap_does_not_affect_other_devices(client, session_id):
    for i in range(5):
        client.post(
            f"{API}/sessions/{session_id}/checkin",
            json={
                "name": f"A{i}",
                "age": 14,
                "skill_level": "beginner",
                "device_id": "device-one",
            },
        )

    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={
            "name": "Different phone",
            "age": 14,
            "skill_level": "beginner",
            "device_id": "device-two",
        },
    )
    assert response.status_code == 201


def test_name_whitespace_is_normalised(client, session_id, check_in):
    check_in(session_id, "  Juan   Dela  Cruz ")
    assert client.get(f"{API}/sessions/{session_id}/attendees").json()[0]["name"] == (
        "Juan Dela Cruz"
    )


def test_checkin_blocked_on_closed_session(client, session_id):
    client.patch(f"{API}/sessions/{session_id}", json={"status": "closed"})
    response = client.post(
        f"{API}/sessions/{session_id}/checkin",
        json={"name": "Late", "age": 14, "skill_level": "intermediate"},
    )
    assert response.status_code == 409

    # ...but the organizer can still add manually.
    assert (
        client.post(
            f"{API}/sessions/{session_id}/attendees",
            json={"name": "Late", "age": 14, "skill_level": "intermediate"},
        ).status_code
        == 201
    )


def test_checkin_to_unknown_session_returns_404(client):
    response = client.post(
        f"{API}/sessions/424242/checkin",
        json={"name": "Ghost", "age": 12, "skill_level": "intermediate"},
    )
    assert response.status_code == 404


# ── teams ─────────────────────────────────────────────────────────────────


def _fill(check_in, session_id, count: int, skill: str = "beginner") -> list[int]:
    return [check_in(session_id, f"{skill.title()}{i}", 14, skill) for i in range(count)]


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


def test_late_arrival_is_auto_placed_after_generate(client, session_id, check_in):
    """Prevents needing a reshuffle: a check-in after generate is slotted
    straight onto the best-fit team, not left for a manual Add tap."""
    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    late_id = check_in(session_id, "Late Larry", 15, "intermediate")

    body = client.get(f"{API}/sessions/{session_id}/teams").json()
    assert body["unassigned"] == []
    placed_ids = [m["attendee_id"] for t in body["teams"] for m in t["members"]]
    assert late_id in placed_ids

    late_member = next(
        m for t in body["teams"] for m in t["members"] if m["attendee_id"] == late_id
    )
    assert late_member["added_via"] == "manual-add"

    picker = client.get(f"{API}/sessions/{session_id}/attendees/unassigned").json()
    assert picker == []

    attendee = next(
        a
        for a in client.get(f"{API}/sessions/{session_id}/attendees").json()
        if a["id"] == late_id
    )
    assert attendee["added_via"] == "manual-add"
    assert attendee["team_id"] is not None


def test_late_arrival_auto_placement_does_not_disturb_existing_rosters(
    client, session_id, check_in
):
    """The Section 6.2 guarantee, now exercised via automatic placement
    instead of an explicit /teams/add-player call."""
    _fill(check_in, session_id, 9)  # 5v5 -> Team A (5, full), Team B (4, room)
    before = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    snapshot = {
        team["team_name"]: sorted(m["attendee_id"] for m in team["members"])
        for team in before["teams"]
    }

    late_id = check_in(session_id, "Late Larry", 15, "intermediate")
    after = client.get(f"{API}/sessions/{session_id}/teams").json()

    assert {t["team_name"] for t in after["teams"]} == set(snapshot), (
        "a late registration with room to spare should not create a new team"
    )
    for team in after["teams"]:
        original = snapshot[team["team_name"]]
        now = sorted(m["attendee_id"] for m in team["members"])
        assert set(original).issubset(set(now)), "an existing player was moved"
        assert set(now) - set(original) in ({late_id}, set())

    all_now = [m["attendee_id"] for t in after["teams"] for m in t["members"]]
    assert late_id in all_now
    assert after["unassigned"] == []


def test_late_registration_fills_a_vacant_slot_regardless_of_skill(client, session_id, check_in):
    """No synergy: a late registration goes wherever there's room, never by
    skill — even a lopsided-skill team gets the next check-in if it has space."""
    _fill(check_in, session_id, 9)  # 5v5 -> Team A (5), Team B (4): B has room
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_b_id = next(t["team_id"] for t in generated["teams"] if t["team_name"] == "Team B")

    late_id = check_in(session_id, "Late Larry Two", 16, "intermediate")
    after = client.get(f"{API}/sessions/{session_id}/teams").json()

    landed = next(
        team["team_id"]
        for team in after["teams"]
        if any(m["attendee_id"] == late_id for m in team["members"])
    )
    assert landed == team_b_id
    assert next(
        m["added_via"]
        for team in after["teams"]
        for m in team["members"]
        if m["attendee_id"] == late_id
    ) == "manual-add"


def test_late_registration_prefers_the_last_team_with_a_vacant_slot(client, session_id, check_in):
    client.patch(f"{API}/sessions/{session_id}", json={"team_format": "3v3"})
    _fill(check_in, session_id, 6)  # 3v3 -> Team A (3), Team B (3)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    assert generated["team_format"] == "3v3"

    # Delete one player from each team so both have exactly one vacant slot.
    victims = [team["members"][0]["attendee_id"] for team in generated["teams"]]
    for victim in victims:
        client.delete(f"{API}/sessions/{session_id}/attendees/{victim}")

    late_id = check_in(session_id, "Tail Filler")
    after = client.get(f"{API}/sessions/{session_id}/teams").json()
    team_b_id = next(t["team_id"] for t in after["teams"] if t["team_name"] == "Team B")

    landed = next(
        team["team_id"]
        for team in after["teams"]
        if any(m["attendee_id"] == late_id for m in team["members"])
    )
    assert landed == team_b_id, "should have filled the LAST team with room, not the first"


def test_late_registration_starts_a_new_team_when_every_team_is_full(client, session_id, check_in):
    _fill(check_in, session_id, 5)  # 5v5 -> one full Team A
    client.post(f"{API}/sessions/{session_id}/teams/generate")

    first_overflow = check_in(session_id, "Overflow One", 14)
    after_first = client.get(f"{API}/sessions/{session_id}/teams").json()
    assert [t["team_name"] for t in after_first["teams"]] == ["Team A", "Team B"]
    team_b = next(t for t in after_first["teams"] if t["team_name"] == "Team B")
    assert [m["attendee_id"] for m in team_b["members"]] == [first_overflow]

    # A second late registration fills that same new team rather than
    # spawning yet another one.
    second_overflow = check_in(session_id, "Overflow Two", 14)
    after_second = client.get(f"{API}/sessions/{session_id}/teams").json()
    assert [t["team_name"] for t in after_second["teams"]] == ["Team A", "Team B"]
    team_b_now = next(t for t in after_second["teams"] if t["team_name"] == "Team B")
    assert sorted(m["attendee_id"] for m in team_b_now["members"]) == sorted(
        [first_overflow, second_overflow]
    )


def test_manual_add_after_generate_is_auto_placed(client, session_id, check_in):
    """Same auto-placement for the organizer's manual-add endpoint."""
    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")

    response = client.post(
        f"{API}/sessions/{session_id}/attendees",
        json={"name": "Walked In", "age": 14, "skill_level": "beginner"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["team_id"] is not None
    assert body["added_via"] == "manual-add"

    assert client.get(f"{API}/sessions/{session_id}/attendees/unassigned").json() == []


def test_checkin_before_generate_stays_unassigned(client, session_id, check_in):
    """No teams exist yet, so there's nothing to auto-place into — this is
    the normal pre-generate check-in flow, not a late registration."""
    attendee_id = check_in(session_id, "Early Bird")
    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    body = next(a for a in attendees if a["id"] == attendee_id)
    assert body["team_id"] is None
    assert body["added_via"] is None


def test_generate_draft_members_show_added_via_generate(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    assert all(a["added_via"] == "generate" for a in attendees)


def test_add_player_twice_returns_409(client, session_id, check_in):
    ids = _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    response = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": ids[0]}
    )
    assert response.status_code == 409


def test_add_player_before_generate_returns_409(client, session_id, check_in):
    late_id = check_in(session_id, "Solo", 14, "intermediate")
    response = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": late_id}
    )
    assert response.status_code == 409


def test_add_player_from_another_session_returns_404(client, session_id, check_in):
    other = client.post(
        f"{API}/sessions", json={"session_date": "2026-09-01", "team_format": "5v5"}
    ).json()["id"]
    outsider = check_in(other, "Outsider", 14, "intermediate")

    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    response = client.post(
        f"{API}/sessions/{session_id}/teams/add-player", json={"attendee_id": outsider}
    )
    assert response.status_code == 404


def test_regenerate_wipes_manual_adds(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    check_in(session_id, "Late", 15, "intermediate")  # auto-placed as manual-add

    after = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    assert all(
        m["added_via"] == "generate" for team in after["teams"] for m in team["members"]
    )
    placed = [m["attendee_id"] for team in after["teams"] for m in team["members"]]
    assert sorted(placed) == sorted(placed) and len(placed) == 6


# ── stats ─────────────────────────────────────────────────────────────────


def test_stats_breakdown(client, session_id, check_in):
    check_in(session_id, "A", 14, "intermediate")
    check_in(session_id, "B", 14, "intermediate")
    check_in(session_id, "C", 16, "intermediate")
    client.post(
        f"{API}/sessions/{session_id}/attendees",
        json={"name": "D", "age": 13, "skill_level": "beginner"},
    )
    client.post(f"{API}/sessions/{session_id}/teams/generate")

    stats = client.get(f"{API}/sessions/{session_id}/stats").json()
    assert stats["total_attendance"] == 4
    assert stats["skill_breakdown"] == {"beginner": 1, "intermediate": 3}
    assert stats["source_breakdown"] == {"qr": 3, "manual": 1}
    assert stats["team_count"] == 1
    assert stats["assigned_count"] == 4
    assert stats["unassigned_count"] == 0
    assert stats["average_age"] == 14.2  # (14+14+16+13)/4 = 14.25, rounded to 1dp


def test_stats_on_empty_session(client, session_id):
    stats = client.get(f"{API}/sessions/{session_id}/stats").json()
    assert stats["total_attendance"] == 0
    assert stats["average_age"] is None
    assert stats["skill_breakdown"] == {"beginner": 0, "intermediate": 0}


# ── session deletion cascades ─────────────────────────────────────────────


def test_session_counts_are_reported(client, session_id, check_in):
    _fill(check_in, session_id, 6)
    client.post(f"{API}/sessions/{session_id}/teams/generate")
    body = client.get(f"{API}/sessions/{session_id}").json()
    assert body["attendee_count"] == 6
    assert body["team_count"] == 2


# ── game results (win/lose record system) ───────────────────────────────────


def test_recording_a_result_updates_member_win_loss_tally(client, session_id, check_in):
    ids = _fill(check_in, session_id, 5)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_id = generated["teams"][0]["team_id"]
    member_ids = {m["attendee_id"] for m in generated["teams"][0]["members"]}

    response = client.post(
        f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "win"}
    )
    assert response.status_code == 201
    body = response.json()

    for team in body["teams"]:
        for member in team["members"]:
            if member["attendee_id"] in member_ids and team["team_id"] == team_id:
                assert member["wins"] == 1
                assert member["losses"] == 0

    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    for attendee in attendees:
        if attendee["id"] in member_ids:
            assert attendee["wins"] == 1
            assert attendee["losses"] == 0
    assert ids  # sanity: fixture actually returned ids


def test_a_team_can_be_marked_multiple_times_a_session(client, session_id, check_in):
    """It's a record system, not a single overwritable field."""
    _fill(check_in, session_id, 5)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_id = generated["teams"][0]["team_id"]
    a_member_id = generated["teams"][0]["members"][0]["attendee_id"]

    client.post(f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "win"})
    client.post(f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "win"})
    final = client.post(
        f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "lose"}
    ).json()

    member = next(
        m
        for team in final["teams"]
        for m in team["members"]
        if m["attendee_id"] == a_member_id
    )
    assert member["wins"] == 2
    assert member["losses"] == 1

    history = client.get(f"{API}/sessions/{session_id}/results").json()
    assert len(history) == 3
    assert [r["result"] for r in history] == ["lose", "win", "win"]  # newest first


def test_individual_result_survives_a_reshuffle(client, session_id, check_in):
    """The whole point: attendees keep their win/lose history even after
    teams/generate wipes and rebuilds every team."""
    ids = _fill(check_in, session_id, 5)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_id = generated["teams"][0]["team_id"]
    original_member_ids = {m["attendee_id"] for m in generated["teams"][0]["members"]}

    client.post(f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "win"})

    # Reshuffle — every team/team_member row is deleted and recreated.
    client.post(f"{API}/sessions/{session_id}/teams/generate")

    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    for attendee in attendees:
        if attendee["id"] in original_member_ids:
            assert attendee["wins"] == 1, "individual result did not survive the reshuffle"

    # The history log itself is untouched by the reshuffle: the record still
    # exists with its result and team_name intact, only team_id is nulled out
    # since that specific team row was deleted by the regenerate.
    history = client.get(f"{API}/sessions/{session_id}/results").json()
    assert len(history) == 1
    assert history[0]["result"] == "win"
    assert history[0]["team_id"] is None
    assert history[0]["team_name"] == "Team A"
    assert ids


def test_recording_result_for_unknown_team_returns_404(client, session_id):
    response = client.post(
        f"{API}/sessions/{session_id}/teams/999999/results", json={"result": "win"}
    )
    assert response.status_code == 404


def test_recording_result_for_team_in_another_session_returns_404(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_id = generated["teams"][0]["team_id"]

    other = client.post(
        f"{API}/sessions", json={"session_date": "2026-09-01", "team_format": "5v5"}
    ).json()["id"]

    response = client.post(
        f"{API}/sessions/{other}/teams/{team_id}/results", json={"result": "win"}
    )
    assert response.status_code == 404


def test_recording_result_rejects_bad_value(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_id = generated["teams"][0]["team_id"]

    response = client.post(
        f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "draw"}
    )
    assert response.status_code == 422


def test_delete_result_undoes_a_mistaken_marking(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_id = generated["teams"][0]["team_id"]
    a_member_id = generated["teams"][0]["members"][0]["attendee_id"]

    client.post(f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "lose"})
    result_id = client.get(f"{API}/sessions/{session_id}/results").json()[0]["id"]

    delete_response = client.delete(f"{API}/sessions/{session_id}/results/{result_id}")
    assert delete_response.status_code == 200

    attendees = client.get(f"{API}/sessions/{session_id}/attendees").json()
    member = next(a for a in attendees if a["id"] == a_member_id)
    assert member["wins"] == 0
    assert member["losses"] == 0
    assert client.get(f"{API}/sessions/{session_id}/results").json() == []


def test_delete_result_cross_session_returns_404(client, session_id, check_in):
    _fill(check_in, session_id, 5)
    generated = client.post(f"{API}/sessions/{session_id}/teams/generate").json()
    team_id = generated["teams"][0]["team_id"]
    client.post(f"{API}/sessions/{session_id}/teams/{team_id}/results", json={"result": "win"})
    result_id = client.get(f"{API}/sessions/{session_id}/results").json()[0]["id"]

    other = client.post(
        f"{API}/sessions", json={"session_date": "2026-09-01", "team_format": "5v5"}
    ).json()["id"]

    response = client.delete(f"{API}/sessions/{other}/results/{result_id}")
    assert response.status_code == 404
