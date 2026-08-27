"""Queries for the ``teams`` / ``team_members`` tables.

This module persists whatever ``app.services.team_balancer`` decided. It
contains no balancing rules of its own.
"""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import func, delete, select
from sqlalchemy.orm import Session as DbSession, selectinload

from app.models import Attendee, Team, TeamMember
from app.services.team_balancer import (
    BalancingError,
    Player,
    TeamSize,
    pick_vacant_team,
    team_label,
    team_size_for_format,
)


def list_with_members(db: DbSession, session_id: int) -> list[Team]:
    stmt = (
        select(Team)
        .where(Team.session_id == session_id)
        .options(selectinload(Team.members).selectinload(TeamMember.attendee))
        .order_by(Team.id.asc())
    )
    return list(db.scalars(stmt))


def get(db: DbSession, team_id: int) -> Team | None:
    return db.get(Team, team_id)


def get_with_members(db: DbSession, team_id: int) -> Team | None:
    """Same as :func:`get`, but with the roster eager-loaded — needed before
    recording a result, since every current member gets snapshotted."""
    stmt = select(Team).where(Team.id == team_id).options(selectinload(Team.members))
    return db.scalars(stmt).first()


def players_for_session(db: DbSession, session_id: int) -> list[Player]:
    """Every attendee of the session, reduced to what the algorithm needs."""
    rows = db.execute(
        select(Attendee.id, Attendee.skill_level)
        .where(Attendee.session_id == session_id)
        .order_by(Attendee.id.asc())
    ).all()
    return [Player(attendee_id=attendee_id, skill_level=skill) for attendee_id, skill in rows]


def replace_teams(
    db: DbSession,
    session_id: int,
    drafted: Sequence[Sequence[Player]],
) -> list[Team]:
    """Destructively swap in a freshly drafted roster (spec Section 6.1 step 8).

    Deleting the ``teams`` rows cascades to ``team_members``; attendees are
    untouched. The whole swap is one transaction, so a failure mid-way leaves
    the previous roster intact rather than a half-built one.
    """
    existing_team_ids = list(
        db.scalars(select(Team.id).where(Team.session_id == session_id))
    )
    if existing_team_ids:
        db.execute(delete(TeamMember).where(TeamMember.team_id.in_(existing_team_ids)))
        db.execute(delete(Team).where(Team.id.in_(existing_team_ids)))
        db.flush()

    created: list[Team] = []
    for index, roster in enumerate(drafted):
        team = Team(session_id=session_id, team_name=team_label(index))
        db.add(team)
        db.flush()  # assigns team.id
        for player in roster:
            db.add(
                TeamMember(
                    team_id=team.id,
                    attendee_id=player.attendee_id,
                    added_via="generate",
                )
            )
        created.append(team)

    db.commit()
    return list_with_members(db, session_id)


def team_sizes(db: DbSession, session_id: int) -> list[TeamSize]:
    """Current headcount of each team, in team order — the late-arrival
    ("late registration") decision only ever needs capacity, never skill."""
    rows = db.execute(
        select(Team.id, func.count(TeamMember.id))
        .select_from(Team)
        .outerjoin(TeamMember, TeamMember.team_id == Team.id)
        .where(Team.session_id == session_id)
        .group_by(Team.id)
        .order_by(Team.id.asc())
    ).all()
    return [TeamSize(team_id=team_id, member_count=int(count)) for team_id, count in rows]


def is_assigned(db: DbSession, attendee_id: int) -> bool:
    return (
        db.scalar(select(TeamMember.id).where(TeamMember.attendee_id == attendee_id))
        is not None
    )


def add_member(db: DbSession, team_id: int, attendee_id: int) -> TeamMember:
    """Place one late arrival without disturbing existing assignments."""
    member = TeamMember(team_id=team_id, attendee_id=attendee_id, added_via="manual-add")
    db.add(member)
    db.commit()
    db.refresh(member)
    return member


def place_if_possible(
    db: DbSession,
    session_id: int,
    attendee_id: int,
    team_format: str,
) -> int | None:
    """Auto-slot a just-created attendee into a team, if rosters already exist.

    Called right after check-in / manual-add so a late arrival ("late
    registration") never has to sit in the "waiting to be placed" queue for
    an organizer to notice — this is what keeps a late arrival from forcing a
    full reshuffle. No skill balancing: whoever still has a vacant slot gets
    them, preferring the last such team; if every team is already full, a
    fresh one is created and becomes the new tail of the roster.

    A no-op (returns ``None``) when no teams exist yet at all for this
    session — that's the normal pre-generate check-in flow, not a late
    registration.
    """
    sizes = team_sizes(db, session_id)
    if not sizes:
        return None

    capacity = team_size_for_format(team_format)
    target_team_id = pick_vacant_team(sizes, capacity)

    if target_team_id is None:
        # Every existing team is full — this new team becomes the tail that
        # subsequent late registrations fill, until it's full too.
        team = Team(session_id=session_id, team_name=team_label(len(sizes)))
        db.add(team)
        db.flush()  # assigns team.id
        target_team_id = team.id

    add_member(db, target_team_id, attendee_id)
    return target_team_id


def assigned_count(db: DbSession, session_id: int) -> int:
    rows = db.execute(
        select(TeamMember.id).join(Team).where(Team.session_id == session_id)
    ).all()
    return len(rows)
