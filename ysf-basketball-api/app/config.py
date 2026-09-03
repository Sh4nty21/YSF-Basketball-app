"""Application configuration.

Responsibility: read environment variables and expose them as one typed,
validated settings object. Nothing else in the codebase should touch
``os.environ`` directly.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Values allowed by the database CHECK constraints (spec Section 4). Kept here
# so schemas, services and migrations all agree on one definition.
SKILL_LEVELS: tuple[str, ...] = ("beginner", "intermediate")
TEAM_FORMATS: tuple[str, ...] = ("5v5", "4v4", "3v3")
TEAM_RESULTS: tuple[str, ...] = ("win", "lose")
SESSION_STATUSES: tuple[str, ...] = ("open", "closed")
ATTENDEE_SOURCES: tuple[str, ...] = ("qr", "manual")
ADDED_VIA_VALUES: tuple[str, ...] = ("generate", "manual-add")

# Multi-sport expansion (NEW_PROJECT_PLAN.md).
SPORTS: tuple[str, ...] = ("basketball", "volleyball", "badminton")

# Volleyball check-in collects a position instead of a skill level — skill
# is deliberately not used for volleyball team generation at all.
VOLLEYBALL_POSITIONS: tuple[str, ...] = (
    "outside_hitter",
    "middle_blocker",
    "setter",
    "opposite",
)

# Badminton's per-session mode, chosen the same way basketball picks a team
# format — Singles (tier-segregated 1-on-1 pairing) or Doubles (tier-
# segregated 2-person teams).
BADMINTON_MODES: tuple[str, ...] = ("singles", "doubles")

# Admin accounts (NEW_PROJECT_PLAN.md). Exactly two roles: super_admin can
# create/revoke other admins, admin has full equal session/roster/team
# functionality across every sport.
ADMIN_ROLES: tuple[str, ...] = ("super_admin", "admin")


def _normalise_driver(url: str) -> str:
    """Force SQLAlchemy to use the psycopg 3 driver.

    Supabase (and every hosting dashboard) hands out URLs starting with
    ``postgresql://`` or ``postgres://``. SQLAlchemy maps the bare
    ``postgresql://`` prefix to psycopg2, which we do not install, so we
    rewrite the prefix instead of asking the user to edit their URL.
    """
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]
    if url.startswith("postgresql://"):
        url = "postgresql+psycopg://" + url[len("postgresql://") :]
    return url


class Settings(BaseSettings):
    """Typed view of the ``.env`` file / process environment."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Runtime connection. Defaults to a local SQLite file so a fresh clone can
    # boot and be explored before Supabase is wired up; production always sets
    # this to the Supabase pooler URI.
    database_url: str = "sqlite:///./ysf_local.db"

    # Migrations need Supabase's DIRECT connection (port 5432) rather than the
    # transaction pooler (6543). Falls back to database_url when unset.
    migration_database_url: str = ""

    cors_origins: str = "*"

    min_age: int = 13
    max_age: int = 22

    # One-time bootstrap for the very first super-admin account. There is no
    # public registration route and every other way to create an admin
    # requires an existing super-admin, so this env-var pair is the only way
    # the first account can ever come to exist. Checked once at startup
    # (app.main.bootstrap_first_super_admin) and only takes effect while the
    # admins table is still empty — safe to leave set permanently afterward.
    bootstrap_admin_username: str = ""
    bootstrap_admin_password: str = ""

    checkin_base_url: str = "http://localhost:5500"

    # Anti-flooding: max self-check-ins the same browser/device may submit for
    # a single session. Enforced via the client-generated `device_id` field.
    checkin_device_limit: int = 5

    app_name: str = "YSF Basketball API"
    api_prefix: str = "/api/v1"

    @field_validator("database_url", "migration_database_url")
    @classmethod
    def _fix_driver(cls, value: str) -> str:
        return _normalise_driver(value) if value else value

    @property
    def sqlalchemy_url(self) -> str:
        return self.database_url

    @property
    def alembic_url(self) -> str:
        return self.migration_database_url or self.database_url

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def is_sqlite(self) -> bool:
        return self.sqlalchemy_url.startswith("sqlite")

    def checkin_url_for(self, session_id: int) -> str:
        """URL a participant lands on after scanning the session's QR code."""
        return f"{self.checkin_base_url.rstrip('/')}?session={session_id}"


@lru_cache
def get_settings() -> Settings:
    """Cached accessor so the ``.env`` file is parsed exactly once."""
    return Settings()


settings = get_settings()

__all__ = [
    "ADDED_VIA_VALUES",
    "ADMIN_ROLES",
    "ATTENDEE_SOURCES",
    "BADMINTON_MODES",
    "SESSION_STATUSES",
    "SKILL_LEVELS",
    "SPORTS",
    "TEAM_FORMATS",
    "TEAM_RESULTS",
    "VOLLEYBALL_POSITIONS",
    "Settings",
    "get_settings",
    "settings",
]
