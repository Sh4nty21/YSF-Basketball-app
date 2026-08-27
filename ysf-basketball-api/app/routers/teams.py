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
from app.repositories import attendees_repo, results_repo, teams_repo
from app.schemas import AddPlayerRequest, GameResultCreate, TeamsResponse
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
        results_repo.wins_losses_by_attendee(db, session.id),
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
    """Manual fallback for the same "late registration" placement that
    already happens automatically at check-in — fills whichever team still
    has a vacant slot (last one first), or starts a fresh team if every
    existing one is full. No skill balancing: disturbs nobody else."""
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

    target_team_id = teams_repo.place_if_possible(
        db, session.id, attendee.id, session.team_format
    )
    if target_team_id is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No teams exist for this session yet — generate teams first.",
        )

    return _current_state(db, session)


@router.post(
    "/{session_id}/teams/{team_id}/results",
    response_model=TeamsResponse,
    status_code=status.HTTP_201_CREATED,
)
def record_team_result(
    team_id: int,
    payload: GameResultCreate,
    session: Session = Depends(get_existing_session),
    db: DbSession = Depends(get_db),
) -> TeamsResponse:
    """Record a win/lose for this team's CURRENT roster.

    Always creates a new record — a team plays more than once a session, so
    this is a log, not a field to overwrite. Every attendee currently on the
    team is snapshotted into the record, which is what lets their individual
    win/lose history survive a later reshuffle (spec: "mark players
    individually ... in case they got reshuffled").
    """
    team = teams_repo.get_with_members(db, team_id)
    if team is None or team.session_id != session.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Team {team_id} was not found in this session.",
        )
    if not team.members:
        # Defensive: the snake draft never actually produces an empty team
        # (num_teams is always <= player count), but this guard stays cheap
        # insurance against a future change to that invariant.
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This team has no players yet — nothing to record a result for.",
        )

    results_repo.create(db, session.id, team, payload.result)
    return _current_state(db, session)
