"""Add fields needed to actually generate teams for volleyball and badminton.

Three changes, all additive/loosening — nothing destructive:

- `attendees.skill_level` becomes nullable: volleyball check-ins don't
  collect a skill level at all (they collect `position` instead — skill
  is deliberately not used for volleyball team generation, see
  NEW_PROJECT_PLAN.md). Existing basketball/badminton rows are untouched;
  the API layer still requires skill_level for those sports.
- `attendees.position` (new, nullable) — volleyball only: one of
  outside_hitter / middle_blocker / setter / opposite.
- `sessions.badminton_mode` (new, nullable) — badminton only: singles or
  doubles, chosen per-session the same way basketball picks a team format.

Revision ID: 0005_volleyball_badminton_fields
Revises: 0004_admin_accounts_and_sport
Create Date: 2026-09-03
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0005_volleyball_badminton_fields"
down_revision: Union[str, None] = "0004_admin_accounts_and_sport"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

OLD_SKILL_CHECK = "skill_level IN ('beginner','intermediate')"
NEW_SKILL_CHECK = "skill_level IS NULL OR skill_level IN ('beginner','intermediate')"
POSITION_CHECK = (
    "position IS NULL OR position IN "
    "('outside_hitter','middle_blocker','setter','opposite')"
)
BADMINTON_MODE_CHECK = "badminton_mode IS NULL OR badminton_mode IN ('singles','doubles')"


def upgrade() -> None:
    with op.batch_alter_table("attendees") as batch_op:
        batch_op.alter_column("skill_level", existing_type=sa.String(length=20), nullable=True)
        batch_op.drop_constraint("ck_attendees_skill_level", type_="check")
        batch_op.create_check_constraint("ck_attendees_skill_level", NEW_SKILL_CHECK)
        batch_op.add_column(sa.Column("position", sa.String(length=20), nullable=True))
        batch_op.create_check_constraint("ck_attendees_position", POSITION_CHECK)

    with op.batch_alter_table("sessions") as batch_op:
        batch_op.add_column(sa.Column("badminton_mode", sa.String(length=10), nullable=True))
        batch_op.create_check_constraint("ck_sessions_badminton_mode", BADMINTON_MODE_CHECK)


def downgrade() -> None:
    with op.batch_alter_table("sessions") as batch_op:
        batch_op.drop_constraint("ck_sessions_badminton_mode", type_="check")
        batch_op.drop_column("badminton_mode")

    with op.batch_alter_table("attendees") as batch_op:
        batch_op.drop_constraint("ck_attendees_position", type_="check")
        batch_op.drop_column("position")
        batch_op.drop_constraint("ck_attendees_skill_level", type_="check")
        batch_op.create_check_constraint("ck_attendees_skill_level", OLD_SKILL_CHECK)
        # Note: any rows with skill_level NULL (volleyball check-ins) will
        # fail this constraint on downgrade — expected, since downgrading
        # past this migration means volleyball check-ins shouldn't exist.
        batch_op.alter_column("skill_level", existing_type=sa.String(length=20), nullable=False)
