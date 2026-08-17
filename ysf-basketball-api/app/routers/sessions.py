"""Session CRUD — ``/sessions`` (organizer)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.dependencies import get_existing_session
from app.models import Session
from app.presenters import session_to_schema
from app.repositories import sessions_repo
from app.schemas import SessionCreate, SessionRead, SessionUpdate
from app.security import require_organizer

router = APIRouter(
    prefix="/sessions",
    tags=["sessions"],
    dependencies=[Depends(require_organizer)],
)


@router.post("", response_model=SessionRead, status_code=status.HTTP_201_CREATED)
def create_session(payload: SessionCreate, db: DbSession = Depends(get_db)) -> SessionRead:
    """Create a weekly session. Starts with status ``open``."""
    session = sessions_repo.create(db, payload)
    return session_to_schema(session, attendee_count=0, team_count=0)


@router.get("", response_model=list[SessionRead])
def list_sessions(
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    db: DbSession = Depends(get_db),
) -> list[SessionRead]:
    """Session history, most recent first."""
    sessions = sessions_repo.list_all(db, limit=limit, offset=offset)
    counts = sessions_repo.counts_for_many(db, [s.id for s in sessions])
    return [
        session_to_schema(s, *counts.get(s.id, (0, 0)))
        for s in sessions
    ]


@router.get("/{session_id}", response_model=SessionRead)
def get_session(
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> SessionRead:
    attendee_count, team_count = sessions_repo.counts_for(db, session.id)
    return session_to_schema(session, attendee_count, team_count)


@router.patch("/{session_id}", response_model=SessionRead)
def update_session(
    payload: SessionUpdate,
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> SessionRead:
    """Update ``team_format``, ``status`` or ``week_label``.

    Changing ``team_format`` does not re-shuffle anyone; the organizer must
    press "Generate Teams" again for the new format to take effect.
    """
    if not payload.model_dump(exclude_unset=True):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide at least one of: team_format, status, week_label.",
        )
    updated = sessions_repo.update(db, session, payload)
    attendee_count, team_count = sessions_repo.counts_for(db, updated.id)
    return session_to_schema(updated, attendee_count, team_count)
