"""Team endpoints — generate, add late player, read rosters.

All decisions are delegated to ``app.services.team_balancer``; this module only
moves data between the database and HTTP.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.dependencies import get_existing_session
from app.models import Session
from app.presenters import teams_to_schema
from app.repositories import attendees_repo, teams_repo
from app.schemas import AddPlayerRequest, TeamsResponse
from app.security import require_organizer
from app.services import team_balancer

router = APIRouter(
    prefix="/sessions",
    tags=["teams"],
    dependencies=[Depends(require_organizer)],
)


def _current_state(db: DbSession, session: Session) -> TeamsResponse:
    return teams_to_schema(
        session,
        teams_repo.list_with_members(db, session.id),
        attendees_repo.list_unassigned(db, session.id),
    )


@router.get("/{session_id}/teams", response_model=TeamsResponse)
def get_teams(
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> TeamsResponse:
    """Current rosters plus anyone still waiting to be placed."""
    return _current_state(db, session)


@router.post("/{session_id}/teams/generate", response_model=TeamsResponse)
def generate_teams(
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> TeamsResponse:
    """Full reshuffle via snake draft — **destructive**.

    Every existing placement for this session (including manual late-arrival
    adds) is discarded and rebuilt. The Flutter app asks for confirmation
    before calling this.
    """
    players = teams_repo.players_for_session(db, session.id)
    try:
        drafted = team_balancer.generate_teams(players, session.team_format)
    except team_balancer.BalancingError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc

    teams_repo.replace_teams(db, session.id, drafted)
    return _current_state(db, session)


@router.post("/{session_id}/teams/add-player", response_model=TeamsResponse)
def add_player(
    payload: AddPlayerRequest,
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> TeamsResponse:
    """Slot ONE late arrival into the best-fit team, disturbing nobody else."""
    attendee = attendees_repo.get(db, payload.attendee_id)
    if attendee is None or attendee.session_id != session.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Attendee {payload.attendee_id} is not part of session {session.id}.",
        )
    if teams_repo.is_assigned(db, attendee.id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"{attendee.name} is already on a team for this session.",
        )

    try:
        target_team_id = team_balancer.pick_best_fit_team(
            teams_repo.compositions(db, session.id),
            attendee.skill_level,
        )
    except team_balancer.BalancingError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc

    teams_repo.add_member(db, target_team_id, attendee.id)
    return _current_state(db, session)
