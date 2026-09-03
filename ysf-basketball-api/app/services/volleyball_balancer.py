"""Volleyball team generation — role-quota drafting, not skill-based.

Pure functions only, mirrors ``app.services.team_balancer``'s shape: no
database, no HTTP, no framework imports.

Two-phase algorithm (NEW_PROJECT_PLAN.md, decided 2026-09-03):

* **Phase 1 (up to 6 teams)**: the number of teams scales with headcount
  (same idea as basketball's "how many teams does this many players need"),
  capped at 6 — so a 6-person roster forms 1 real team, not 6 near-empty
  ones. At the cap, that's a target quota of 12 Outside Hitters, 12 Middle
  Blockers, 6 Setters, 6 Opposites — 6 teams' worth at the standard 2 OH /
  2 MB / 1 Setter / 1 Opposite recipe. Each position pool is shuffled and
  dealt round-robin across however many Phase 1 teams there are, so a
  shortage or surplus in any one role is spread as fairly as possible
  instead of leaving one team incomplete while another is full.
* **Phase 2 (overflow)**: once more players remain in a position pool after
  the first 6 teams are filled, additional overflow teams are created, each
  following the same standard recipe, repeating Phase 1's round-robin
  fair-mixing within the overflow group.

Skill level plays no part in this at all — a deliberate departure from
basketball/badminton, per the plan.
"""

from __future__ import annotations

import random
from typing import NamedTuple, Sequence

POSITIONS: tuple[str, ...] = ("outside_hitter", "middle_blocker", "setter", "opposite")

# The standard per-team recipe — also what an overflow team uses.
PER_TEAM: dict[str, int] = {
    "outside_hitter": 2,
    "middle_blocker": 2,
    "setter": 1,
    "opposite": 1,
}

BASE_TEAMS = 6
TEAM_SIZE = sum(PER_TEAM.values())  # 6


class VolleyballPlayer(NamedTuple):
    attendee_id: int
    position: str


class TeamPositionCounts(NamedTuple):
    """One existing team's current per-position headcount, used by
    :func:`pick_vacant_team_for_position` — the volleyball equivalent of
    ``team_balancer.TeamSize``."""

    team_id: int
    counts: dict[str, int]


class BalancingError(ValueError):
    """Raised when the requested balancing operation is impossible."""


def pick_vacant_team_for_position(
    teams: Sequence[TeamPositionCounts], position: str
) -> int | None:
    """Choose which existing team a late-arriving volleyball player should
    join — the team still needing this exact position, not just any vacant
    seat (spec-equivalent of ``team_balancer.pick_vacant_team``, but
    position-aware since volleyball's roster shape is fixed by role, not a
    flat headcount).

    Preference goes to the LAST team still short that position, so late
    arrivals build up at the tail of the roster rather than sprinkled back
    through the earlier teams — same convention as basketball.

    Returns ``None`` if every team already has its full quota of this
    position — the caller's cue to start a brand new team instead.
    """
    quota = PER_TEAM.get(position)
    if quota is None:
        raise BalancingError(f"unknown position: {position!r}")

    for team in reversed(teams):
        if team.counts.get(position, 0) < quota:
            return team.team_id
    return None


def _deal_round_robin(pool: Sequence[VolleyballPlayer], num_teams: int) -> list[list[VolleyballPlayer]]:
    """Distribute ``pool`` across ``num_teams`` buckets one at a time — the
    plan's fairness mechanism: a short pool simply leaves later teams with
    fewer of that role, rather than any one team looking wildly different
    from another."""
    teams: list[list[VolleyballPlayer]] = [[] for _ in range(num_teams)]
    for index, player in enumerate(pool):
        teams[index % num_teams].append(player)
    return teams


def generate_volleyball_teams(
    players: Sequence[VolleyballPlayer],
    rng: random.Random | None = None,
) -> list[list[VolleyballPlayer]]:
    """Returns a list of rosters (each a list of players) — Phase 1's teams
    first, then any Phase 2 overflow teams. Empty teams are dropped (can
    only happen if a position pool is completely empty for that slot)."""
    if not players:
        raise BalancingError("cannot build teams: no attendees have checked in yet")

    generator = rng or random.Random()

    by_position: dict[str, list[VolleyballPlayer]] = {p: [] for p in POSITIONS}
    for player in players:
        if player.position not in by_position:
            raise BalancingError(f"unknown position: {player.position!r}")
        by_position[player.position].append(player)
    for pool in by_position.values():
        generator.shuffle(pool)

    # ── Phase 1: up to BASE_TEAMS, quota-limited per role ────────────────
    # The number of Phase 1 teams scales with how many players actually
    # showed up (same "how many teams does this headcount need" idea as
    # basketball's required_team_count), capped at BASE_TEAMS — a 6-person
    # roster should form 1 real team, not get spread thin across 6 empty
    # ones. Only once total headcount would need MORE than BASE_TEAMS does
    # the cap actually bind, and Phase 2 below picks up the rest.
    total_players = len(players)
    target_teams = min(BASE_TEAMS, max(1, -(-total_players // TEAM_SIZE)))

    phase1_teams: list[list[VolleyballPlayer]] = [[] for _ in range(target_teams)]
    overflow_pools: dict[str, list[VolleyballPlayer]] = {}
    for position, per_team in PER_TEAM.items():
        quota = per_team * target_teams
        pool = by_position[position]
        overflow_pools[position] = pool[quota:]
        dealt = _deal_round_robin(pool[:quota], target_teams)
        for team_index, members in enumerate(dealt):
            phase1_teams[team_index].extend(members)

    teams = [team for team in phase1_teams if team]

    # ── Phase 2: overflow, same recipe, repeated ─────────────────────────
    remaining_total = sum(len(pool) for pool in overflow_pools.values())
    if remaining_total > 0:
        num_overflow_teams = max(
            -(-len(overflow_pools[position]) // per_team)  # ceiling division
            for position, per_team in PER_TEAM.items()
        )
        num_overflow_teams = max(1, num_overflow_teams)

        overflow_teams: list[list[VolleyballPlayer]] = [
            [] for _ in range(num_overflow_teams)
        ]
        for position in POSITIONS:
            dealt = _deal_round_robin(overflow_pools[position], num_overflow_teams)
            for team_index, members in enumerate(dealt):
                overflow_teams[team_index].extend(members)

        teams.extend(team for team in overflow_teams if team)

    return teams
