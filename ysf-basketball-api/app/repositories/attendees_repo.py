"""Queries for the ``attendees`` table."""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session as DbSession, selectinload

from app.models import Attendee, Team, TeamMember
from app.schemas import AttendeeCreate


def create(
    db: DbSession,
    session_id: int,
    payload: AttendeeCreate,
    source: str,
) -> Attendee:
    """Insert a check-in. ``source`` is set by the endpoint, not the client."""
    attendee = Attendee(
        session_id=session_id,
        name=payload.name,
        age=payload.age,
        skill_level=payload.skill_level,
        position=payload.position,
        source=source,
        device_id=payload.device_id,
    )
    db.add(attendee)
    db.commit()
    db.refresh(attendee)
    return attendee


def count_by_device(db: DbSession, session_id: int, device_id: str) -> int:
    """How many attendees this device has already checked in for this session."""
    return db.scalar(
        select(func.count(Attendee.id)).where(
            Attendee.session_id == session_id,
            Attendee.device_id == device_id,
        )
    ) or 0


def get(db: DbSession, attendee_id: int) -> Attendee | None:
    return db.get(Attendee, attendee_id)


def delete(db: DbSession, attendee: Attendee) -> None:
    """Delete an attendee registration from the current session."""
    db.delete(attendee)
    db.commit()


def list_for_session(db: DbSession, session_id: int) -> list[Attendee]:
    """Live check-in list, newest last (arrival order)."""
    stmt = (
        select(Attendee)
        .where(Attendee.session_id == session_id)
        .options(selectinload(Attendee.membership).selectinload(TeamMember.team))
        .order_by(Attendee.checked_in_at.asc(), Attendee.id.asc())
    )
    return list(db.scalars(stmt))


def list_unassigned(db: DbSession, session_id: int) -> list[Attendee]:
    """Attendees with no ``team_members`` row yet — i.e. late arrivals."""
    assigned = (
        select(TeamMember.attendee_id)
        .join(Team)
        .where(Team.session_id == session_id)
    )
    stmt = (
        select(Attendee)
        .where(
            Attendee.session_id == session_id,
            Attendee.id.not_in(assigned),
        )
        .order_by(Attendee.checked_in_at.asc(), Attendee.id.asc())
    )
    return list(db.scalars(stmt))


def skill_breakdown(db: DbSession, session_id: int) -> dict[str, int]:
    rows = db.execute(
        select(Attendee.skill_level, func.count(Attendee.id))
        .where(Attendee.session_id == session_id)
        .group_by(Attendee.skill_level)
    ).all()
    return {skill: int(total) for skill, total in rows}


def source_breakdown(db: DbSession, session_id: int) -> dict[str, int]:
    rows = db.execute(
        select(Attendee.source, func.count(Attendee.id))
        .where(Attendee.session_id == session_id)
        .group_by(Attendee.source)
    ).all()
    return {source: int(total) for source, total in rows}


def average_age(db: DbSession, session_id: int) -> float | None:
    value = db.scalar(
        select(func.avg(Attendee.age)).where(Attendee.session_id == session_id)
    )
    return round(float(value), 1) if value is not None else None


def team_placement(attendee: Attendee) -> tuple[int | None, str | None, str | None]:
    """``(team_id, team_name, added_via)`` for an attendee, or all-``None`` if unplaced.

    ``added_via`` distinguishes the original draft (``generate``) from anyone
    slotted in afterward (``manual-add``) — the latter is what the app labels
    "Late registration".
    """
    membership = attendee.membership
    if membership is None or membership.team is None:
        return None, None, None
    return membership.team.id, membership.team.team_name, membership.added_via