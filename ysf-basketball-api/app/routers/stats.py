"""Attendance statistics — ``GET /sessions/{id}/stats``."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.dependencies import get_existing_session
from app.models import Session
from app.repositories import attendees_repo, sessions_repo, teams_repo
from app.schemas import SessionStats
from app.security import require_admin
from app.services.statistics import build_stats

router = APIRouter(
    prefix="/sessions",
    tags=["stats"],
    dependencies=[Depends(require_admin)],
)


@router.get("/{session_id}/stats", response_model=SessionStats)
def get_stats(
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> SessionStats:
    """Total attendance plus skill-level and check-in-source breakdowns."""
    _, team_count = sessions_repo.counts_for(db, session.id)
    return build_stats(
        session_id=session.id,
        session_date=session.session_date,
        week_label=session.week_label,
        team_format=session.team_format,
        status=session.status,
        skill_counts=attendees_repo.skill_breakdown(db, session.id),
        source_counts=attendees_repo.source_breakdown(db, session.id),
        team_count=team_count,
        assigned_count=teams_repo.assigned_count(db, session.id),
        average_age=attendees_repo.average_age(db, session.id),
    )
