"""Badminton pairing — skill-tier-segregated, for both Singles and Doubles.

Pure functions only, mirrors ``app.services.team_balancer``'s shape.

Per NEW_PROJECT_PLAN.md (decided 2026-09-03):

* **Doubles**: the same random-team mechanic as basketball, but tiers never
  mix — a beginner-only pool and an intermediate-only pool are each
  independently, randomly paired into 2-person teams.
* **Singles**: random 1-on-1 opponent pairing within a skill tier — the
  same tier-segregated pool concept as Doubles, just pairs of 1-on-1
  opponents rather than 2-person partnerships.
* **Remainder**: an unpaired odd-one-out in a tier sits unassigned/waiting
  rather than being placed cross-tier. This function simply omits that
  player from every returned roster — the existing "unassigned" query
  (nobody on a ``team_members`` row) picks them up for free, no separate
  bookkeeping needed.

Singles and Doubles share the exact same pairing shape (2 people per
roster, tier-segregated) — the only real difference between the two modes
is what that pairing *means* (opponents vs. partners), which is a
presentation/labeling concern for the caller, not a drafting one. So one
function serves both.
"""

from __future__ import annotations

import random
from typing import NamedTuple, Sequence

# Drafted intermediate-first, same convention as team_balancer.DRAFT_ORDER —
# not load-bearing here since tiers never mix, just kept consistent.
TIERS: tuple[str, ...] = ("intermediate", "beginner")


class BadmintonPlayer(NamedTuple):
    attendee_id: int
    skill_level: str


class BalancingError(ValueError):
    """Raised when the requested balancing operation is impossible."""


def generate_badminton_pairs(
    players: Sequence[BadmintonPlayer],
    rng: random.Random | None = None,
) -> list[list[BadmintonPlayer]]:
    """Returns a list of 2-person rosters — used for both Singles (opponent
    matchups) and Doubles (partnerships); the router decides which label to
    apply. A tier's odd-one-out is simply left off the result."""
    if not players:
        raise BalancingError("cannot build teams: no attendees have checked in yet")

    generator = rng or random.Random()

    pairs: list[list[BadmintonPlayer]] = []
    for tier in TIERS:
        pool = [player for player in players if player.skill_level == tier]
        generator.shuffle(pool)
        for index in range(0, len(pool) - 1, 2):
            pairs.append([pool[index], pool[index + 1]])
        # A trailing unpaired player in this tier is deliberately left off
        # every roster — they surface via the unassigned-players query.

    return pairs
