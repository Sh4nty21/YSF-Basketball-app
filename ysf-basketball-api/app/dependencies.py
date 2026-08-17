"""Shared FastAPI dependencies."""

from __future__ import annotations

from fastapi import Depends, HTTPException, Path, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.models import Session
from app.repositories import sessions_repo


def get_existing_session(
    session_id: int = Path(..., ge=1, description="Session id"),
    db: DbSession = Depends(get_db),
) -> Session:
    """Resolve ``{session_id}`` or return a clean 404.

    Used by every nested route so the "does this session exist?" check is
    written once.
    """
    session = sessions_repo.get(db, session_id)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Session {session_id} was not found.",
        )
    return session
