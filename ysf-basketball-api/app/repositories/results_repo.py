"""Queries for the ``game_results`` / ``game_result_players`` tables.

The win/lose record system: append-only, so ``create`` is the only write that
adds a row — there is no update, only "record another one" or "delete this
one" (for correcting a mistake).
"""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session as DbSession, selectinload

from app.models import GameResult, GameResultPlayer, Team
from app.presenters import WinLossTally


def create(db: DbSession, session_id: int, team: Team, result: str) -> GameResult:
    """Record a new result for ``team``'s CURRENT roster.

    ``team.members`` must already be loaded (selectinload) by the caller.
    """
    record = GameResult(
        session_id=session_id,
        team_id=team.id,
        team_name=team.team_name,
        result=result,
    )
    db.add(record)
    db.flush()  # assigns record.id

    for member in team.members:
        db.add(GameResultPlayer(game_result_id=record.id, attendee_id=member.attendee_id))

    db.commit()
    db.refresh(record)
    return record


def list_for_session(db: DbSession, session_id: int) -> list[GameResult]:
    stmt = (
        select(GameResult)
        .where(GameResult.session_id == session_id)
        .options(selectinload(GameResult.players).selectinload(GameResultPlayer.attendee))
        .order_by(GameResult.recorded_at.desc(), GameResult.id.desc())
    )
    return list(db.scalars(stmt))


def get(db: DbSession, result_id: int) -> GameResult | None:
    return db.get(GameResult, result_id)


def delete(db: DbSession, record: GameResult) -> None:
    db.delete(record)
    db.commit()


def wins_losses_by_attendee(db: DbSession, session_id: int) -> WinLossTally:
    """``{attendee_id: (wins, losses)}`` across every recorded result this session."""
    rows = db.execute(
        select(GameResultPlayer.attendee_id, GameResult.result, func.count())
        .select_from(GameResultPlayer)
        .join(GameResult, GameResult.id == GameResultPlayer.game_result_id)
        .where(GameResult.session_id == session_id)
        .group_by(GameResultPlayer.attendee_id, GameResult.result)
    ).all()

    tally: WinLossTally = {}
    for attendee_id, result, count in rows:
        wins, losses = tally.get(attendee_id, (0, 0))
        if result == "win":
            wins += count
        else:
            losses += count
        tally[attendee_id] = (wins, losses)
    return tally
