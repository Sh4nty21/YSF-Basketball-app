"""Initial schema: sessions, attendees, teams, team_members.

Mirrors spec Section 4 one-for-one, including every CHECK constraint.

Revision ID: 0001_initial
Revises:
Create Date: 2026-08-17
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "sessions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("session_date", sa.Date(), nullable=False),
        sa.Column("week_label", sa.String(length=50), nullable=True),
        sa.Column("team_format", sa.String(length=10), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.CheckConstraint(
            "team_format IN ('5v5','4v4','3v3')", name="ck_sessions_team_format"
        ),
        sa.CheckConstraint("status IN ('open','closed')", name="ck_sessions_status"),
    )

    op.create_table(
        "attendees",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("session_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("age", sa.Integer(), nullable=False),
        sa.Column("skill_level", sa.String(length=20), nullable=False),
        sa.Column("source", sa.String(length=10), nullable=False, server_default="qr"),
        sa.Column("checked_in_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(
            ["session_id"], ["sessions.id"], ondelete="CASCADE",
            name="fk_attendees_session_id",
        ),
        sa.CheckConstraint("age > 0 AND age < 100", name="ck_attendees_age"),
        sa.CheckConstraint(
            "skill_level IN ('beginner','intermediate','pro')",
            name="ck_attendees_skill_level",
        ),
        sa.CheckConstraint("source IN ('qr','manual')", name="ck_attendees_source"),
    )
    op.create_index("ix_attendees_session_id", "attendees", ["session_id"])

    op.create_table(
        "teams",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("session_id", sa.Integer(), nullable=False),
        sa.Column("team_name", sa.String(length=50), nullable=False),
        sa.ForeignKeyConstraint(
            ["session_id"], ["sessions.id"], ondelete="CASCADE",
            name="fk_teams_session_id",
        ),
    )
    op.create_index("ix_teams_session_id", "teams", ["session_id"])

    op.create_table(
        "team_members",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("team_id", sa.Integer(), nullable=False),
        sa.Column("attendee_id", sa.Integer(), nullable=False),
        sa.Column("added_via", sa.String(length=20), nullable=False, server_default="generate"),
        sa.Column("added_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(
            ["team_id"], ["teams.id"], ondelete="CASCADE", name="fk_team_members_team_id"
        ),
        sa.ForeignKeyConstraint(
            ["attendee_id"], ["attendees.id"], ondelete="CASCADE",
            name="fk_team_members_attendee_id",
        ),
        # One team per attendee per session.
        sa.UniqueConstraint("attendee_id", name="uq_team_members_attendee"),
        sa.CheckConstraint(
            "added_via IN ('generate','manual-add')", name="ck_team_members_added_via"
        ),
    )
    op.create_index("ix_team_members_team_id", "team_members", ["team_id"])


def downgrade() -> None:
    op.drop_index("ix_team_members_team_id", table_name="team_members")
    op.drop_table("team_members")
    op.drop_index("ix_teams_session_id", table_name="teams")
    op.drop_table("teams")
    op.drop_index("ix_attendees_session_id", table_name="attendees")
    op.drop_table("attendees")
    op.drop_table("sessions")
