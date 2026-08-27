"""Drop the 'pro' skill tier, add attendees.device_id for check-in rate limiting.

Two changes:

1. skill_level now only allows 'beginner' / 'intermediate' (dropped 'pro').
   Any existing rows already tagged 'pro' are remapped to 'intermediate' so
   they stay valid and attendance history is not deleted — just recategorised
   into the tier immediately below the one being retired. This step is NOT
   reversible: downgrade() restores the wider CHECK constraint but cannot
   tell which 'intermediate' rows used to say 'pro'.

2. attendees.device_id (nullable) + a supporting index, so the public
   check-in endpoint can cap how many people the same browser/device may
   register for one session (anti-flooding).

Revision ID: 0002_two_skill_levels
Revises: 0001_initial
Create Date: 2026-08-27
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0002_two_skill_levels"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

OLD_CHECK = "skill_level IN ('beginner','intermediate','pro')"
NEW_CHECK = "skill_level IN ('beginner','intermediate')"


def upgrade() -> None:
    # Remap historical 'pro' rows before the stricter constraint would reject them.
    op.execute("UPDATE attendees SET skill_level = 'intermediate' WHERE skill_level = 'pro'")

    # Batch mode: SQLite (local/dev) cannot ALTER a CHECK constraint directly and
    # needs the copy-and-move strategy; on Postgres (production) batch mode just
    # issues the equivalent ALTER statements natively, so this one path works
    # for both backends.
    with op.batch_alter_table("attendees") as batch_op:
        batch_op.drop_constraint("ck_attendees_skill_level", type_="check")
        batch_op.create_check_constraint("ck_attendees_skill_level", NEW_CHECK)
        batch_op.add_column(sa.Column("device_id", sa.String(length=64), nullable=True))
        batch_op.create_index(
            "ix_attendees_session_device", ["session_id", "device_id"]
        )


def downgrade() -> None:
    with op.batch_alter_table("attendees") as batch_op:
        batch_op.drop_index("ix_attendees_session_device")
        batch_op.drop_column("device_id")
        batch_op.drop_constraint("ck_attendees_skill_level", type_="check")
        batch_op.create_check_constraint("ck_attendees_skill_level", OLD_CHECK)
    # Note: rows remapped 'pro' -> 'intermediate' during upgrade() are not
    # restored to 'pro' — that information was intentionally discarded.
