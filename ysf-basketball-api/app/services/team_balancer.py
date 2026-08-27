"""Team balancing — the core business logic (spec Section 6).

Pure functions only: no database, no HTTP, no framework imports. The
repository layer feeds these functions plain ``Player`` tuples and persists
whatever comes back.

Two operations:

* :func:`generate_teams` — full reshuffle via a continuous snake draft
  (destructive; overwrites the existing roster).
* :func:`pick_vacant_team` — slot ONE late arrival ("late registration") into
  whichever team still has room, touching nobody else's placement and with no
  skill balancing at all — a late arrival is filled in wherever there's a
  spot, not fought over for team composition.
"""

from __future__ import annotations

import math
import random
import string
from typing import NamedTuple, Sequence

# Skill tiers are drafted strongest-first so that the snake pattern hands the
# scarce "intermediate" players out one per team before anyone gets a second.
DRAFT_ORDER: tuple[str, ...] = ("intermediate", "beginner")

TEAM_SIZE_BY_FORMAT: dict[str, int] = {"5v5": 5, "4v4": 4, "3v3": 3}


class Player(NamedTuple):
    """The only thing the algorithm needs to know about an attendee."""

    attendee_id: int
    skill_level: str


class TeamSize(NamedTuple):
    """One existing team's current headcount, used by :func:`pick_vacant_team`."""

    team_id: int
    member_count: int


class BalancingError(ValueError):
    """Raised when the requested balancing operation is impossible."""


# ── helpers ───────────────────────────────────────────────────────────────


def team_size_for_format(team_format: str) -> int:
    """Players per team for a ``5v5`` / ``4v4`` / ``3v3`` session."""
    try:
        return TEAM_SIZE_BY_FORMAT[team_format]
    except KeyError as exc:  # pragma: no cover - guarded by schema validation
        raise BalancingError(f"unknown team_format: {team_format!r}") from exc


def required_team_count(total_players: int, team_size: int) -> int:
    """``ceil(total / team_size)``, with at least one team when anybody showed up.

    A 3-player 5v5 session still produces one team rather than zero, so the
    organizer can see the roster and add late arrivals to it.
    """
    if total_players <= 0:
        raise BalancingError("cannot build teams: no attendees have checked in yet")
    return max(1, math.ceil(total_players / team_size))


def team_label(index: int) -> str:
    """``0 -> "Team A"``, ``25 -> "Team Z"``, ``26 -> "Team AA"``."""
    if index < 0:
        raise BalancingError("team index must not be negative")
    letters = string.ascii_uppercase
    name = ""
    position = index
    while True:
        name = letters[position % 26] + name
        position = position // 26 - 1
        if position < 0:
            break
    return f"Team {name}"


def _draft_queue(players: Sequence[Player], rng: random.Random) -> list[Player]:
    """Shuffle within each skill tier, then concatenate intermediate -> beginner."""
    by_skill: dict[str, list[Player]] = {tier: [] for tier in DRAFT_ORDER}
    for player in players:
        if player.skill_level not in by_skill:
            raise BalancingError(f"unknown skill_level: {player.skill_level!r}")
        by_skill[player.skill_level].append(player)

    queue: list[Player] = []
    for tier in DRAFT_ORDER:
        tier_players = by_skill[tier]
        rng.shuffle(tier_players)
        queue.extend(tier_players)
    return queue


def snake_draft(queue: Sequence[Player], num_teams: int) -> list[list[Player]]:
    """Deal an already-ordered queue across ``num_teams`` in snake order.

    Round 0 runs left-to-right (Team A, B, C...), round 1 runs right-to-left
    (C, B, A), and so on. Because the snake is *continuous* across the three
    skill tiers rather than restarting per tier, the leftovers of a tier are
    handed to whichever teams are next in the rotation — which is exactly the
    remainder-spreading behaviour required by spec Section 6.1 step 7.
    """
    if num_teams < 1:
        raise BalancingError("num_teams must be at least 1")

    teams: list[list[Player]] = [[] for _ in range(num_teams)]
    for position, player in enumerate(queue):
        round_index, slot = divmod(position, num_teams)
        target = slot if round_index % 2 == 0 else num_teams - 1 - slot
        teams[target].append(player)
    return teams


# ── public operations ─────────────────────────────────────────────────────


def generate_teams(
    players: Sequence[Player],
    team_format: str,
    rng: random.Random | None = None,
) -> list[list[Player]]:
    """Full reshuffle (spec Section 6.1).

    Returns a list of teams, each a list of players. Index 0 becomes "Team A".
    Pass ``rng`` (e.g. ``random.Random(42)``) to make the result reproducible
    in tests.
    """
    generator = rng or random.Random()
    team_size = team_size_for_format(team_format)
    num_teams = required_team_count(len(players), team_size)
    queue = _draft_queue(players, generator)
    return snake_draft(queue, num_teams)


def pick_vacant_team(sizes: Sequence[TeamSize], capacity: int) -> int | None:
    """Choose which existing team a late registration should join.

    Deliberately not skill-aware — a late arrival is "just added there with
    no synergy since they are late and are least priority" (spec): they fill
    whichever team still has room, full stop. Preference goes to the LAST
    team with a vacant slot, so late registrations build up at the tail of
    the roster rather than being sprinkled back through the earlier teams.

    Returns ``None`` if every team is already at ``capacity`` — the caller's
    cue to start a brand new team instead (that new team then becomes the
    natural target for the next one, until it too fills up).

    Raises if ``sizes`` is empty: that means no teams exist for this session
    at all yet, which is a different situation from "every team is full"
    (the caller must ``generate`` first).
    """
    if not sizes:
        raise BalancingError(
            "no teams exist for this session yet — generate teams before adding a late player"
        )

    for team in reversed(sizes):
        if team.member_count < capacity:
            return team.team_id
    return None
