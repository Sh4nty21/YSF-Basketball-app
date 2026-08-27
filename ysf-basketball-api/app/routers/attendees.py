"""Organizer attendee endpoints — manual add, live check-in list, and deletion."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.dependencies import get_existing_session
from app.models import Session
from app.presenters import attendee_to_schema
from app.repositories import attendees_repo, results_repo, teams_repo
from app.schemas import AttendeeCreate, AttendeeRead
from app.security import require_organizer

router = APIRouter(
    prefix="/sessions",
    tags=["attendees"],
    dependencies=[Depends(require_organizer)],
)


@router.post(
    "/{session_id}/attendees",
    response_model=AttendeeRead,
    status_code=status.HTTP_201_CREATED,
)
def add_attendee(
    payload: AttendeeCreate,
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> AttendeeRead:
    """Organizer backup entry — records source='manual'."""

    attendee = attendees_repo.create(
        db,
        session.id,
        payload,
        source="manual",
    )
    db.refresh(attendee)
    # Same auto-placement as public check-in: if rosters already exist, slot
    # this person straight into a vacant slot ("Late registration") instead
    # of leaving them for a second manual add-player step.
    teams_repo.place_if_possible(db, session.id, attendee.id, session.team_format)
    db.refresh(attendee)
    return attendee_to_schema(attendee)


@router.get(
    "/{session_id}/attendees",
    response_model=list[AttendeeRead],
)
def list_attendees(
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> list[AttendeeRead]:
    """Live check-in list in arrival order, including team placement if any."""

    attendees = attendees_repo.list_for_session(db, session.id)
    tally = results_repo.wins_losses_by_attendee(db, session.id)
    return [attendee_to_schema(attendee, tally) for attendee in attendees]


@router.get(
    "/{session_id}/attendees/unassigned",
    response_model=list[AttendeeRead],
)
def list_unassigned_attendees(
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> list[AttendeeRead]:
    """Attendees not yet on a team — the Add Late Player picker list."""

    attendees = attendees_repo.list_unassigned(db, session.id)
    tally = results_repo.wins_losses_by_attendee(db, session.id)
    return [attendee_to_schema(attendee, tally) for attendee in attendees]


@router.delete(
    "/{session_id}/attendees/{attendee_id}",
    status_code=status.HTTP_200_OK,
)
def delete_attendee(
    attendee_id: int,
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> dict[str, str]:
    """Organizer can remove a duplicate or incorrect registration."""

    attendee = attendees_repo.get(db, attendee_id)

    if attendee is None or attendee.session_id != session.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendee not found in this session.",
        )

    attendees_repo.delete(db, attendee)

    return {"message": "Attendee deleted successfully."}