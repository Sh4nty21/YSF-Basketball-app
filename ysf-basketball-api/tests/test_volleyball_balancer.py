"""Unit tests for the volleyball role-quota drafting algorithm — no DB, no
HTTP. See NEW_PROJECT_PLAN.md for the decided two-phase rules being tested
here.
"""

from __future__ import annotations

import random

import pytest

from app.services import volleyball_balancer as vb


def players(**counts: int) -> list[vb.VolleyballPlayer]:
    """``players(outside_hitter=12, setter=6)`` -> tagged Player tuples."""
    result: list[vb.VolleyballPlayer] = []
    next_id = 1
    for position, total in counts.items():
        for _ in range(total):
            result.append(vb.VolleyballPlayer(attendee_id=next_id, position=position))
            next_id += 1
    return result


def counts_by_position(team: list[vb.VolleyballPlayer]) -> dict[str, int]:
    tally: dict[str, int] = {}
    for player in team:
        tally[player.position] = tally.get(player.position, 0) + 1
    return tally


def test_no_attendees_is_an_error():
    with pytest.raises(vb.BalancingError):
        vb.generate_volleyball_teams([])


def test_exact_six_teams_worth_gives_the_standard_recipe_per_team():
    pool = players(outside_hitter=12, middle_blocker=12, setter=6, opposite=6)
    teams = vb.generate_volleyball_teams(pool, rng=random.Random(1))

    assert len(teams) == 6
    for team in teams:
        assert len(team) == 6
        assert counts_by_position(team) == {
            "outside_hitter": 2,
            "middle_blocker": 2,
            "setter": 1,
            "opposite": 1,
        }

    # Nobody lost, nobody duplicated.
    placed_ids = {player.attendee_id for team in teams for player in team}
    assert placed_ids == {player.attendee_id for player in pool}


def test_short_role_is_mixed_fairly_across_six_teams_not_left_incomplete():
    # Only 8 outside hitters instead of the 12-quota, everything else full.
    pool = players(outside_hitter=8, middle_blocker=12, setter=6, opposite=6)
    teams = vb.generate_volleyball_teams(pool, rng=random.Random(2))

    assert len(teams) == 6
    oh_counts = sorted(counts_by_position(team).get("outside_hitter", 0) for team in teams)
    # 8 spread across 6 teams round-robin -> two teams get 2, four get 1.
    assert oh_counts == [1, 1, 1, 1, 2, 2]
    # Every team still has its other three roles at full quota.
    for team in teams:
        tally = counts_by_position(team)
        assert tally.get("middle_blocker") == 2
        assert tally.get("setter") == 1
        assert tally.get("opposite") == 1


def test_surplus_beyond_six_teams_forms_an_overflow_team():
    # A full 6 teams' worth, plus exactly one more full team's worth extra.
    pool = players(outside_hitter=14, middle_blocker=14, setter=7, opposite=7)
    teams = vb.generate_volleyball_teams(pool, rng=random.Random(3))

    # 6 base teams + at least 1 overflow team.
    assert len(teams) >= 7
    placed_ids = {player.attendee_id for team in teams for player in team}
    assert placed_ids == {player.attendee_id for player in pool}

    # Every player landed on exactly one team.
    seen: set[int] = set()
    for team in teams:
        for player in team:
            assert player.attendee_id not in seen
            seen.add(player.attendee_id)


def test_unknown_position_is_rejected():
    bad = [vb.VolleyballPlayer(attendee_id=1, position="libero")]
    with pytest.raises(vb.BalancingError):
        vb.generate_volleyball_teams(bad)


def test_small_roster_still_forms_teams_without_crashing():
    # Nowhere near a full 6-team quota — just enough for one team.
    pool = players(outside_hitter=2, middle_blocker=2, setter=1, opposite=1)
    teams = vb.generate_volleyball_teams(pool, rng=random.Random(4))

    placed_ids = {player.attendee_id for team in teams for player in team}
    assert placed_ids == {player.attendee_id for player in pool}
