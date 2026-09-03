"""Unit tests for badminton's skill-tier-segregated pairing — no DB, no HTTP.
Serves both Singles (opponent matchups) and Doubles (partnerships): the
pairing shape is identical, see NEW_PROJECT_PLAN.md.
"""

from __future__ import annotations

import random

import pytest

from app.services import badminton_balancer as bb


def players(**counts: int) -> list[bb.BadmintonPlayer]:
    result: list[bb.BadmintonPlayer] = []
    next_id = 1
    for skill, total in counts.items():
        for _ in range(total):
            result.append(bb.BadmintonPlayer(attendee_id=next_id, skill_level=skill))
            next_id += 1
    return result


def test_no_attendees_is_an_error():
    with pytest.raises(bb.BalancingError):
        bb.generate_badminton_pairs([])


def test_tiers_never_mix():
    pool = players(beginner=4, intermediate=4)
    pairs = bb.generate_badminton_pairs(pool, rng=random.Random(1))

    by_id = {player.attendee_id: player.skill_level for player in pool}
    for pair in pairs:
        assert len(pair) == 2
        tiers = {by_id[player.attendee_id] for player in pair}
        assert len(tiers) == 1, "a pair must never mix beginner and intermediate"


def test_even_counts_pair_everyone():
    pool = players(beginner=4, intermediate=6)
    pairs = bb.generate_badminton_pairs(pool, rng=random.Random(2))

    placed_ids = {player.attendee_id for pair in pairs for player in pair}
    assert placed_ids == {player.attendee_id for player in pool}
    assert len(pairs) == 2 + 3  # 4/2 beginner pairs + 6/2 intermediate pairs


def test_odd_tier_leaves_one_player_unplaced_not_cross_tier():
    # 5 beginners: 2 pairs + 1 leftover, deliberately dropped from the result.
    pool = players(beginner=5, intermediate=4)
    pairs = bb.generate_badminton_pairs(pool, rng=random.Random(3))

    placed_ids = {player.attendee_id for pair in pairs for player in pair}
    beginner_ids = {p.attendee_id for p in pool if p.skill_level == "beginner"}
    intermediate_ids = {p.attendee_id for p in pool if p.skill_level == "intermediate"}

    # All 4 intermediates placed (even count); exactly 4 of the 5 beginners.
    assert intermediate_ids <= placed_ids
    assert len(placed_ids & beginner_ids) == 4
    assert len(beginner_ids - placed_ids) == 1


def test_no_attendee_appears_twice():
    pool = players(beginner=9, intermediate=7)
    pairs = bb.generate_badminton_pairs(pool, rng=random.Random(4))

    seen: set[int] = set()
    for pair in pairs:
        for player in pair:
            assert player.attendee_id not in seen
            seen.add(player.attendee_id)
