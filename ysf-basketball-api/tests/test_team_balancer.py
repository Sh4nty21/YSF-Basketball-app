"""Unit tests for the balancing algorithm (spec Section 6) — no DB, no HTTP.

Per spec Section 9 step 3, this logic is tested in isolation before it is
wired to endpoints.
"""

from __future__ import annotations

import random
from collections import Counter

import pytest

from app.services import team_balancer as tb


def players(**counts: int) -> list[tb.Player]:
    """``players(pro=2, beginner=3)`` -> 5 Player tuples with unique ids."""
    result: list[tb.Player] = []
    next_id = 1
    for skill, total in counts.items():
        for _ in range(total):
            result.append(tb.Player(attendee_id=next_id, skill_level=skill))
            next_id += 1
    return result


# ── helpers ───────────────────────────────────────────────────────────────


def test_team_size_for_format():
    assert tb.team_size_for_format("5v5") == 5
    assert tb.team_size_for_format("4v4") == 4
    assert tb.team_size_for_format("3v3") == 3


def test_unknown_format_rejected():
    with pytest.raises(tb.BalancingError):
        tb.team_size_for_format("2v2")


@pytest.mark.parametrize(
    ("total", "size", "expected"),
    [(10, 5, 2), (11, 5, 3), (1, 5, 1), (3, 3, 1), (7, 3, 3), (12, 4, 3)],
)
def test_required_team_count(total, size, expected):
    assert tb.required_team_count(total, size) == expected


def test_zero_attendees_is_an_error():
    with pytest.raises(tb.BalancingError):
        tb.required_team_count(0, 5)


def test_team_labels_roll_over_past_z():
    assert tb.team_label(0) == "Team A"
    assert tb.team_label(3) == "Team D"
    assert tb.team_label(25) == "Team Z"
    assert tb.team_label(26) == "Team AA"


# ── generate (6.1) ────────────────────────────────────────────────────────


def test_snake_draft_reverses_every_other_round():
    queue = [tb.Player(i, "pro") for i in range(1, 7)]
    teams = tb.snake_draft(queue, num_teams=3)
    # Round 0 -> 1,2,3 left-to-right; round 1 -> 4,5,6 right-to-left.
    assert [[p.attendee_id for p in team] for team in teams] == [[1, 6], [2, 5], [3, 4]]


def test_every_attendee_is_placed_exactly_once():
    roster = players(pro=4, intermediate=7, beginner=9)
    teams = tb.generate_teams(roster, "5v5", rng=random.Random(1))

    placed = [p.attendee_id for team in teams for p in team]
    assert sorted(placed) == sorted(p.attendee_id for p in roster)
    assert len(placed) == len(set(placed)), "an attendee was placed on two teams"


def test_team_count_matches_format():
    teams = tb.generate_teams(players(beginner=20), "5v5", rng=random.Random(2))
    assert len(teams) == 4
    teams = tb.generate_teams(players(beginner=20), "3v3", rng=random.Random(2))
    assert len(teams) == 7  # ceil(20/3)


def test_team_sizes_stay_within_one_of_each_other():
    roster = players(pro=5, intermediate=6, beginner=8)  # 19 players, 5v5 -> 4 teams
    teams = tb.generate_teams(roster, "5v5", rng=random.Random(3))
    sizes = sorted(len(team) for team in teams)
    assert sizes[-1] - sizes[0] <= 1, f"uneven team sizes: {sizes}"


def test_pros_are_spread_not_clustered():
    """The whole point of the snake draft: 4 pros across 4 teams == 1 each."""
    roster = players(pro=4, intermediate=8, beginner=8)
    teams = tb.generate_teams(roster, "5v5", rng=random.Random(4))
    pro_counts = [sum(1 for p in team if p.skill_level == "pro") for team in teams]
    assert sorted(pro_counts) == [1, 1, 1, 1]


def test_skill_spread_within_one_for_every_tier():
    roster = players(pro=6, intermediate=6, beginner=6)  # 18 -> 4 teams at 5v5
    teams = tb.generate_teams(roster, "5v5", rng=random.Random(5))
    for tier in tb.DRAFT_ORDER:
        counts = [sum(1 for p in team if p.skill_level == tier) for team in teams]
        assert max(counts) - min(counts) <= 1, f"{tier} clustered: {counts}"


def test_fewer_players_than_one_full_team_still_produces_one_team():
    teams = tb.generate_teams(players(beginner=3), "5v5", rng=random.Random(6))
    assert len(teams) == 1
    assert len(teams[0]) == 3


def test_same_seed_gives_the_same_draft():
    roster = players(pro=3, intermediate=4, beginner=5)
    first = tb.generate_teams(roster, "4v4", rng=random.Random(99))
    second = tb.generate_teams(roster, "4v4", rng=random.Random(99))
    assert first == second


def test_shuffle_actually_randomises_across_seeds():
    roster = players(beginner=12)
    drafts = {
        tuple(tuple(p.attendee_id for p in team) for team in tb.generate_teams(roster, "4v4", rng=random.Random(seed)))
        for seed in range(15)
    }
    assert len(drafts) > 1, "draft is not being randomised"


def test_generate_rejects_unknown_skill_level():
    with pytest.raises(tb.BalancingError):
        tb.generate_teams([tb.Player(1, "legend")], "5v5", rng=random.Random(0))


# ── add late player (6.2) ─────────────────────────────────────────────────


def composition(team_id: int, **counts: int) -> tb.TeamComposition:
    counter = Counter(counts)
    return tb.TeamComposition(team_id, counter, sum(counter.values()))


def test_late_player_joins_team_with_fewest_of_their_skill():
    compositions = [
        composition(1, pro=2, beginner=1),
        composition(2, pro=0, beginner=3),
        composition(3, pro=1, beginner=2),
    ]
    assert tb.pick_best_fit_team(compositions, "pro") == 2


def test_tie_on_skill_breaks_on_smallest_team():
    compositions = [
        composition(1, pro=0, beginner=4),
        composition(2, pro=0, beginner=1),  # same 0 pros, fewer members overall
        composition(3, pro=0, beginner=3),
    ]
    assert tb.pick_best_fit_team(compositions, "pro") == 2


def test_full_tie_is_deterministic_lowest_team_id():
    compositions = [composition(7, pro=1), composition(3, pro=1), composition(5, pro=1)]
    assert tb.pick_best_fit_team(compositions, "pro") == 3


def test_empty_team_wins_over_populated_ones():
    compositions = [composition(1, beginner=2), composition(2)]
    assert tb.pick_best_fit_team(compositions, "beginner") == 2


def test_add_player_without_any_teams_is_an_error():
    with pytest.raises(tb.BalancingError):
        tb.pick_best_fit_team([], "pro")


def test_add_player_rejects_unknown_skill():
    with pytest.raises(tb.BalancingError):
        tb.pick_best_fit_team([composition(1)], "legend")
