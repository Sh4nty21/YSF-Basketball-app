"""Public QR check-in — ``POST /sessions/{id}/checkin``.

The only endpoint reachable without an organizer key. Kept in its own router
so the organizer dependency can never be attached to it by accident.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_existing_session
from app.models import Session
from app.repositories import attendees_repo, teams_repo
from app.schemas import AttendeeCreate, CheckinResponse
from app.services.attendee_validation import validate_attendee_for_sport

router = APIRouter(prefix="/sessions", tags=["public check-in"])


@router.get(
    "/{session_id}/checkin-info",
    summary="Public: just enough to render the right check-in form",
)
def checkin_info(session: Session = Depends(get_existing_session)) -> dict:
    """The check-in web form needs to know a session's `sport` before it can
    decide whether to show a skill picker or a position picker — but
    `GET /sessions/{id}` is organizer-gated and returns roster-adjacent
    counts that shouldn't be public. This is the minimal public subset:
    nothing here reveals attendance, rosters, or anything else private.
    """
    return {"sport": session.sport, "status": session.status}


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

    if not payload.device_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="device_id is required for check-in.",
        )

    sport_error = validate_attendee_for_sport(session.sport, payload)
    if sport_error:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=sport_error)

    already = attendees_repo.count_by_device(db, session.id, payload.device_id)
    if already >= settings.checkin_device_limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                f"This device has already checked in the maximum of "
                f"{settings.checkin_device_limit} people for this session. "
                "See an organizer if you need to add more."
            ),
        )

    attendee = attendees_repo.create(db, session.id, payload, source="qr")
    # If rosters already exist, slot this late arrival straight onto the
    # vacant slot (or a fresh team if every existing one is full) instead of
    # leaving them for an organizer to place by hand — avoids needing a
    # reshuffle. No-ops before the first generate. Badminton's
    # tier-segregated pairing doesn't have a "vacant slot" concept yet, so
    # late arrivals there stay in the unassigned queue until regenerated.
    if session.sport == "basketball":
        teams_repo.place_if_possible(db, session.id, attendee.id, session.team_format)
    elif session.sport == "volleyball":
        teams_repo.place_volleyball_if_possible(db, session.id, attendee.id, attendee.position)
    return CheckinResponse(
        attendee_id=attendee.id,
        name=attendee.name,
        message=f"You're checked in, {attendee.name}! See you on the court.",
    )
