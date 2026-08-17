"""Public QR check-in — ``POST /sessions/{id}/checkin``.

The only endpoint reachable without an organizer key. Kept in its own router
so the organizer dependency can never be attached to it by accident.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.dependencies import get_existing_session
from app.models import Session
from app.repositories import attendees_repo
from app.schemas import AttendeeCreate, CheckinResponse

router = APIRouter(prefix="/sessions", tags=["public check-in"])


@router.post(
    "/{session_id}/checkin",
    response_model=CheckinResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Public check-in (no auth)",
)
def checkin(
    payload: AttendeeCreate,
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> CheckinResponse:
    """Participant self-check-in from the QR-code web form.

    Records ``source='qr'``. Returns only the submitter's own details — never
    the roster — because this response is visible to the public.
    """
    if session.status == "closed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Check-in for this session is closed. Please see an organizer.",
        )

    attendee = attendees_repo.create(db, session.id, payload, source="qr")
    return CheckinResponse(
        attendee_id=attendee.id,
        name=attendee.name,
        message=f"You're checked in, {attendee.name}! See you on the court.",
    )
