"""Add a win/lose results log for teams (record system, not a single field).

Two new tables:

- game_results — one row per organizer marking. A team can be marked several
  times across a session (it plays more than one game), so this is
  append-only: each POST creates a new row, nothing is overwritten.
  ``team_id`` points at the live team but is nulled (not cascaded) if that
  team is later deleted by a reshuffle; ``team_name`` is a permanent snapshot
  so old records still read sensibly after that.
- game_result_players — which attendees were on the roster at the moment a
  game_results row was created. This is what makes an individual player's
  win/lose history survive a reshuffle: `teams`/`team_members` get wiped and
  recreated by `POST .../teams/generate`, but this table is never touched by
  that operation, so a player's past results stay attributed to them
  regardless of what team they end up on afterward.

Revision ID: 0003_team_results
Revises: 0002_two_skill_levels
Create Date: 2026-08-27
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0003_team_results"
down_revision: Union[str, None] = "0002_two_skill_levels"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "game_results",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("session_id", sa.Integer(), nullable=False),
        sa.Column("team_id", sa.Integer(), nullable=True),
        sa.Column("team_name", sa.String(length=50), nullable=False),
        sa.Column("result", sa.String(length=10), nullable=False),
        sa.Column("recorded_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(
            ["session_id"], ["sessions.id"], ondelete="CASCADE",
            name="fk_game_results_session_id",
        ),
        sa.ForeignKeyConstraint(
            ["team_id"], ["teams.id"], ondelete="SET NULL",
            name="fk_game_results_team_id",
        ),
        sa.CheckConstraint("result IN ('win','lose')", name="ck_game_results_result"),
    )
    op.create_index("ix_game_results_session_id", "game_results", ["session_id"])
    op.create_index("ix_game_results_team_id", "game_results", ["team_id"])

    op.create_table(
        "game_result_players",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("game_result_id", sa.Integer(), nullable=False),
        sa.Column("attendee_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["game_result_id"], ["game_results.id"], ondelete="CASCADE",
            name="fk_game_result_players_game_result_id",
        ),
        sa.ForeignKeyConstraint(
            ["attendee_id"], ["attendees.id"], ondelete="CASCADE",
            name="fk_game_result_players_attendee_id",
        ),
    )
    op.create_index(
        "ix_game_result_players_game_result_id", "game_result_players", ["game_result_id"]
    )
    op.create_index(
        "ix_game_result_players_attendee_id", "game_result_players", ["attendee_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_game_result_players_attendee_id", table_name="game_result_players")
    op.drop_index("ix_game_result_players_game_result_id", table_name="game_result_players")
    op.drop_table("game_result_players")

    op.drop_index("ix_game_results_team_id", table_name="game_results")
    op.drop_index("ix_game_results_session_id", table_name="game_results")
    op.drop_table("game_results")
