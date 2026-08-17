"""Queries for the ``sessions`` table."""

from __future__ import annotations

import datetime as dt

from sqlalchemy import func, select
from sqlalchemy.orm import Session as DbSession

from app.models import Attendee, Session, Team
from app.schemas import SessionCreate, SessionUpdate


def create(db: DbSession, payload: SessionCreate) -> Session:
    session = Session(
        session_date=payload.session_date,
        week_label=payload.week_label,
        team_format=payload.team_format,
        status="open",
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def get(db: DbSession, session_id: int) -> Session | None:
    return db.get(Session, session_id)


def list_all(db: DbSession, limit: int = 200, offset: int = 0) -> list[Session]:
    """History, most recent first (spec Section 5)."""
    stmt = (
        select(Session)
        .order_by(Session.session_date.desc(), Session.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(stmt))


def update(db: DbSession, session: Session, payload: SessionUpdate) -> Session:
    data = payload.model_dump(exclude_unset=True)
    for field, value in data.items():
        setattr(session, field, value)
    db.commit()
    db.refresh(session)
    return session


def counts_for(db: DbSession, session_id: int) -> tuple[int, int]:
    """``(attendee_count, team_count)`` for one session."""
    attendees = db.scalar(
        select(func.count(Attendee.id)).where(Attendee.session_id == session_id)
    )
    teams = db.scalar(select(func.count(Team.id)).where(Team.session_id == session_id))
    return int(attendees or 0), int(teams or 0)


def counts_for_many(db: DbSession, session_ids: list[int]) -> dict[int, tuple[int, int]]:
    """Batch version of :func:`counts_for` — avoids N+1 queries on the list screen."""
    if not session_ids:
        return {}

    attendee_rows = db.execute(
        select(Attendee.session_id, func.count(Attendee.id))
        .where(Attendee.session_id.in_(session_ids))
        .group_by(Attendee.session_id)
    ).all()
    team_rows = db.execute(
        select(Team.session_id, func.count(Team.id))
        .where(Team.session_id.in_(session_ids))
        .group_by(Team.session_id)
    ).all()

    attendees = {session_id: int(total) for session_id, total in attendee_rows}
    teams = {session_id: int(total) for session_id, total in team_rows}
    return {sid: (attendees.get(sid, 0), teams.get(sid, 0)) for sid in session_ids}


def today() -> dt.date:
    return dt.date.today()
