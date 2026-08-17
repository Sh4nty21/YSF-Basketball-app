"""Queries for the ``teams`` / ``team_members`` tables.

This module persists whatever ``app.services.team_balancer`` decided. It
contains no balancing rules of its own.
"""

from __future__ import annotations

from collections import Counter
from typing import Sequence

from sqlalchemy import delete, select
from sqlalchemy.orm import Session as DbSession, selectinload

from app.models import Attendee, Team, TeamMember
from app.services.team_balancer import Player, TeamComposition, team_label


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


def compositions(db: DbSession, session_id: int) -> list[TeamComposition]:
    """Current skill makeup of each team, for the late-arrival decision."""
    rows = db.execute(
        select(Team.id, Attendee.skill_level)
        .select_from(Team)
        .outerjoin(TeamMember, TeamMember.team_id == Team.id)
        .outerjoin(Attendee, Attendee.id == TeamMember.attendee_id)
        .where(Team.session_id == session_id)
        .order_by(Team.id.asc())
    ).all()

    counters: dict[int, Counter] = {}
    for team_id, skill in rows:
        counter = counters.setdefault(team_id, Counter())
        if skill is not None:  # outer join yields NULL for an empty team
            counter[skill] += 1

    return [
        TeamComposition(
            team_id=team_id,
            skill_counts=counter,
            total_members=sum(counter.values()),
        )
        for team_id, counter in counters.items()
    ]


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


def assigned_count(db: DbSession, session_id: int) -> int:
    rows = db.execute(
        select(TeamMember.id).join(Team).where(Team.session_id == session_id)
    ).all()
    return len(rows)
