"""Security hardening pass: brute-force lockout + Row-Level Security.

Two unrelated but both security-motivated changes, bundled into one
migration since neither touches existing data:

1. **Login lockout** — ``admins.failed_login_attempts`` /
   ``admins.locked_until``. Nothing previously rate-limited repeated login
   attempts; an attacker had unlimited guesses at any admin's password,
   including the super-admin's. See ``app/security.py`` for the actual
   lockout logic — this migration only adds the two columns it needs.

2. **Row-Level Security, enabled with zero policies, on every
   application table.** This is specifically a Supabase concern, not a
   general Postgres one: Supabase auto-exposes every table over a public
   REST API (PostgREST) using an "anon" key, UNLESS RLS is enabled on that
   table — regardless of whether anything in this codebase uses that REST
   API. If the project's anon key were ever exposed (bundled into a
   client, committed by mistake, etc.), it would otherwise let anyone read
   or write this entire database directly, completely bypassing FastAPI's
   own auth. Enabling RLS with no policies makes every table default-deny
   for any role that isn't the table owner.

   This assumes the API's own DATABASE_URL connects as the role that
   OWNS these tables (true for a standard Supabase setup, since these
   tables were created via `alembic upgrade` through that same
   connection) — Postgres table owners bypass RLS automatically unless
   `FORCE ROW LEVEL SECURITY` is also set, which this deliberately does
   NOT do, so the backend's own queries are unaffected. If the app's
   connection is ever changed to a non-owning role, it would need an
   explicit permissive policy instead of relying on ownership bypass.

Revision ID: 0006_security_hardening
Revises: 0005_volleyball_badminton_fields
Create Date: 2026-09-03
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0006_security_hardening"
down_revision: Union[str, None] = "0005_volleyball_badminton_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Every application table (not alembic_version, which Postgres/PostgREST
# access patterns don't care about).
_TABLES = (
    "sessions",
    "attendees",
    "teams",
    "team_members",
    "game_results",
    "game_result_players",
    "admins",
    "admin_sessions",
    "audit_log",
)


def upgrade() -> None:
    with op.batch_alter_table("admins") as batch_op:
        batch_op.add_column(
            sa.Column(
                "failed_login_attempts", sa.Integer(), nullable=False, server_default="0"
            )
        )
        batch_op.add_column(sa.Column("locked_until", sa.DateTime(), nullable=True))

    # SQLite (local/dev) has no concept of RLS — this is a Postgres/Supabase-
    # only statement, so skip it entirely rather than have it fail locally.
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        for table in _TABLES:
            op.execute(f'ALTER TABLE "{table}" ENABLE ROW LEVEL SECURITY')


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        for table in _TABLES:
            op.execute(f'ALTER TABLE "{table}" DISABLE ROW LEVEL SECURITY')

    with op.batch_alter_table("admins") as batch_op:
        batch_op.drop_column("locked_until")
        batch_op.drop_column("failed_login_attempts")
