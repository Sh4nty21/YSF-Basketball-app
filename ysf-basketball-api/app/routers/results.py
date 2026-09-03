"""Organizer view of the win/lose record — ``/sessions/{id}/results``.

Recording a new result lives in ``teams.py`` (it's nested under a team id).
This router is read/undo: browse the log, delete a mistaken entry.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.dependencies import get_existing_session
from app.models import Session
from app.presenters import game_result_to_schema
from app.repositories import results_repo
from app.schemas import GameResultRead
from app.security import require_admin

router = APIRouter(
    prefix="/sessions",
    tags=["results"],
    dependencies=[Depends(require_admin)],
)


@router.get("/{session_id}/results", response_model=list[GameResultRead])
def list_results(
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> list[GameResultRead]:
    """Every recorded win/lose for this session, most recent first."""
    records = results_repo.list_for_session(db, session.id)
    return [game_result_to_schema(record) for record in records]


@router.delete("/{session_id}/results/{result_id}", status_code=status.HTTP_200_OK)
def delete_result(
    result_id: int,
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> dict[str, str]:
    """Undo a mistaken marking (e.g. tapped "Lost" instead of "Won")."""
    record = results_repo.get(db, result_id)
    if record is None or record.session_id != session.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Result {result_id} was not found in this session.",
        )
    results_repo.delete(db, record)
    return {"message": "Result deleted successfully."}
