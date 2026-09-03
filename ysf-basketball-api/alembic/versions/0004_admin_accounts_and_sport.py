"""Add admin accounts (appointed-only, session-token auth) and multi-sport tagging.

Three new tables:

- admins — appointed-only accounts (no public registration route exists
  anywhere). Replaces the single shared ``ORGANIZER_API_KEY`` passcode as the
  organizer-endpoint gate. ``role`` is ``super_admin`` (can manage other
  admin accounts) or ``admin`` (equal functionality across every sport).
- admin_sessions — server-side session tokens (not stateless JWTs), so that
  revoking an admin ends their session immediately rather than "can't log in
  next time". Only a sha256 hash of the raw token is ever stored.
- audit_log — a simple, append-only trail of admin-account lifecycle events
  (created/revoked/reactivated/password-changed/login attempts).

Plus one change to ``sessions`` for the multi-sport expansion (basketball /
volleyball / badminton, see NEW_PROJECT_PLAN.md): a new ``sport`` column
(defaults every existing row to ``'basketball'``, so this backfills cleanly),
and ``team_format`` becomes nullable, since volleyball/badminton don't use
the 5v5/4v4/3v3 concept — required only for basketball, enforced at the
Pydantic schema layer rather than a cross-column DB constraint.

Volleyball/badminton team-generation logic itself is NOT part of this
migration — only session tagging/filtering by sport. See NEW_PROJECT_PLAN.md
for the full, already-decided algorithm per sport, to be wired up next.

Revision ID: 0004_admin_accounts_and_sport
Revises: 0003_team_results
Create Date: 2026-09-03
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0004_admin_accounts_and_sport"
down_revision: Union[str, None] = "0003_team_results"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "admins",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("username", sa.String(length=50), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False, server_default="admin"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "must_change_password", sa.Boolean(), nullable=False, server_default=sa.true()
        ),
        sa.Column("sport_tags", sa.String(length=100), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.UniqueConstraint("username", name="uq_admins_username"),
        sa.CheckConstraint("role IN ('super_admin','admin')", name="ck_admins_role"),
    )

    op.create_table(
        "admin_sessions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("admin_id", sa.Integer(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(
            ["admin_id"], ["admins.id"], ondelete="CASCADE",
            name="fk_admin_sessions_admin_id",
        ),
        sa.UniqueConstraint("token_hash", name="uq_admin_sessions_token_hash"),
    )
    op.create_index("ix_admin_sessions_admin_id", "admin_sessions", ["admin_id"])
    op.create_index("ix_admin_sessions_token_hash", "admin_sessions", ["token_hash"])

    op.create_table(
        "audit_log",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("actor_admin_id", sa.Integer(), nullable=True),
        sa.Column("actor_display_name", sa.String(length=100), nullable=False),
        sa.Column("action", sa.String(length=50), nullable=False),
        sa.Column("detail", sa.String(length=200), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(
            ["actor_admin_id"], ["admins.id"], ondelete="SET NULL",
            name="fk_audit_log_actor_admin_id",
        ),
    )

    # sessions.sport — backfills every existing row to 'basketball' via the
    # server default, so nothing pre-existing needs a manual UPDATE first.
    # team_format becomes nullable in the same batch (SQLite can't ALTER a
    # NOT NULL column or add a CHECK constraint outside batch mode; on
    # Postgres batch mode just issues the equivalent ALTER statements
    # natively — same one-path-for-both-backends approach as 0002).
    with op.batch_alter_table("sessions") as batch_op:
        batch_op.add_column(
            sa.Column(
                "sport", sa.String(length=20), nullable=False, server_default="basketball"
            )
        )
        batch_op.create_check_constraint(
            "ck_sessions_sport", "sport IN ('basketball','volleyball','badminton')"
        )
        batch_op.alter_column("team_format", existing_type=sa.String(length=10), nullable=True)


def downgrade() -> None:
    with op.batch_alter_table("sessions") as batch_op:
        batch_op.alter_column("team_format", existing_type=sa.String(length=10), nullable=False)
        batch_op.drop_constraint("ck_sessions_sport", type_="check")
        batch_op.drop_column("sport")

    op.drop_table("audit_log")

    op.drop_index("ix_admin_sessions_token_hash", table_name="admin_sessions")
    op.drop_index("ix_admin_sessions_admin_id", table_name="admin_sessions")
    op.drop_table("admin_sessions")

    op.drop_table("admins")
