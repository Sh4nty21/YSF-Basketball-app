"""SQLAlchemy ORM models — the persistence shape of the system.

Mirrors the SQL in spec Section 4 exactly, including every CHECK constraint,
so the database rejects bad rows even if a bug ever slips past the API layer.
"""

from __future__ import annotations

import datetime as dt

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    func,
    true,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.config import (
    ADDED_VIA_VALUES,
    ADMIN_ROLES,
    ATTENDEE_SOURCES,
    BADMINTON_MODES,
    SESSION_STATUSES,
    SKILL_LEVELS,
    SPORTS,
    TEAM_FORMATS,
    TEAM_RESULTS,
    VOLLEYBALL_POSITIONS,
)
from app.database import Base


def _in_clause(column: str, values: tuple[str, ...]) -> str:
    joined = ",".join(f"'{value}'" for value in values)
    return f"{column} IN ({joined})"


class Session(Base):
    """One weekly fellowship gathering."""

    __tablename__ = "sessions"
    __table_args__ = (
        CheckConstraint(_in_clause("team_format", TEAM_FORMATS), name="ck_sessions_team_format"),
        CheckConstraint(_in_clause("status", SESSION_STATUSES), name="ck_sessions_status"),
        CheckConstraint(_in_clause("sport", SPORTS), name="ck_sessions_sport"),
        CheckConstraint(
            "badminton_mode IS NULL OR "
            + _in_clause("badminton_mode", BADMINTON_MODES),
            name="ck_sessions_badminton_mode",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_date: Mapped[dt.date] = mapped_column(Date, nullable=False)
    week_label: Mapped[str | None] = mapped_column(String(50))
    # Multi-sport expansion. Defaults to basketball so every pre-existing row
    # backfills cleanly. Volleyball/badminton team-generation logic is not
    # built yet (see NEW_PROJECT_PLAN.md) — for now this only tags/filters
    # sessions by sport.
    sport: Mapped[str] = mapped_column(
        String(20), nullable=False, default="basketball", server_default="basketball"
    )
    # NULL for sports that don't use the 5v5/4v4/3v3 concept (volleyball uses
    # a fixed role recipe instead; badminton uses singles/doubles). Required
    # only for basketball — enforced in the Pydantic schema, not the DB,
    # since a DB-level "required unless sport=X" check needs a CHECK
    # expression referencing another column, which SQLite's batch-mode ALTER
    # path used elsewhere in this codebase doesn't need for this case.
    team_format: Mapped[str | None] = mapped_column(String(10), nullable=True)
    # Badminton only — Singles or Doubles, chosen per-session the same way
    # basketball picks a team_format. NULL for every other sport.
    badminton_mode: Mapped[str | None] = mapped_column(String(10), nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="open", server_default="open")
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, server_default=func.now())

    attendees: Mapped[list["Attendee"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="Attendee.checked_in_at",
    )
    teams: Mapped[list["Team"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="Team.id",
    )
    game_results: Mapped[list["GameResult"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="GameResult.id",
    )


class Attendee(Base):
    """A single check-in for a single session.

    Attendance is deliberately per-session: no cross-week identity matching
    (spec Section 4 note).
    """

    __tablename__ = "attendees"
    __table_args__ = (
        CheckConstraint("age > 0 AND age < 100", name="ck_attendees_age"),
        CheckConstraint(
            "skill_level IS NULL OR " + _in_clause("skill_level", SKILL_LEVELS),
            name="ck_attendees_skill_level",
        ),
        CheckConstraint(
            "position IS NULL OR " + _in_clause("position", VOLLEYBALL_POSITIONS),
            name="ck_attendees_position",
        ),
        CheckConstraint(_in_clause("source", ATTENDEE_SOURCES), name="ck_attendees_source"),
        Index("ix_attendees_session_device", "session_id", "device_id"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    age: Mapped[int] = mapped_column(Integer, nullable=False)
    # NULL for volleyball (which uses `position` instead — skill isn't used
    # for volleyball team generation at all); required by the API layer for
    # basketball/badminton, but not enforceable as a DB NOT NULL since the
    # same column serves every sport.
    skill_level: Mapped[str | None] = mapped_column(String(20), nullable=True)
    # Volleyball only. NULL for every other sport.
    position: Mapped[str | None] = mapped_column(String(20), nullable=True)
    source: Mapped[str] = mapped_column(String(10), nullable=False, default="qr", server_default="qr")
    # Client-generated id (localStorage on the web form) used only to enforce
    # the per-session self-check-in cap. Never used to identify a person.
    device_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    checked_in_at: Mapped[dt.datetime] = mapped_column(DateTime, server_default=func.now())

    session: Mapped[Session] = relationship(back_populates="attendees")
    membership: Mapped["TeamMember | None"] = relationship(
        back_populates="attendee",
        cascade="all, delete-orphan",
        uselist=False,
    )


class Team(Base):
    """A team belonging to one session (e.g. "Team A")."""

    __tablename__ = "teams"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    team_name: Mapped[str] = mapped_column(String(50), nullable=False)

    session: Mapped[Session] = relationship(back_populates="teams")
    members: Mapped[list["TeamMember"]] = relationship(
        back_populates="team",
        cascade="all, delete-orphan",
        order_by="TeamMember.id",
    )


class TeamMember(Base):
    """Join row placing one attendee on one team."""

    __tablename__ = "team_members"
    __table_args__ = (
        # An attendee can only be on one team per session.
        UniqueConstraint("attendee_id", name="uq_team_members_attendee"),
        CheckConstraint(_in_clause("added_via", ADDED_VIA_VALUES), name="ck_team_members_added_via"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    team_id: Mapped[int] = mapped_column(
        ForeignKey("teams.id", ondelete="CASCADE"), nullable=False, index=True
    )
    attendee_id: Mapped[int] = mapped_column(
        ForeignKey("attendees.id", ondelete="CASCADE"), nullable=False
    )
    added_via: Mapped[str] = mapped_column(
        String(20), nullable=False, default="generate", server_default="generate"
    )
    added_at: Mapped[dt.datetime] = mapped_column(DateTime, server_default=func.now())

    team: Mapped[Team] = relationship(back_populates="members")
    attendee: Mapped[Attendee] = relationship(back_populates="membership")


class GameResult(Base):
    """One recorded win/lose for one team's roster at one point in time.

    Teams get played multiple times a session, so this is an append-only log,
    not a single mutable field — every organizer marking creates a new row.
    ``team_id`` is a best-effort pointer to the live team (nulled out, not
    cascaded, if that team is later deleted by a reshuffle); ``team_name`` is
    a permanent snapshot so the record still reads sensibly after that happens.
    """

    __tablename__ = "game_results"
    __table_args__ = (
        CheckConstraint(_in_clause("result", TEAM_RESULTS), name="ck_game_results_result"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    team_id: Mapped[int | None] = mapped_column(
        ForeignKey("teams.id", ondelete="SET NULL"), nullable=True, index=True
    )
    team_name: Mapped[str] = mapped_column(String(50), nullable=False)
    result: Mapped[str] = mapped_column(String(10), nullable=False)
    recorded_at: Mapped[dt.datetime] = mapped_column(DateTime, server_default=func.now())

    session: Mapped[Session] = relationship(back_populates="game_results")
    players: Mapped[list["GameResultPlayer"]] = relationship(
        back_populates="game_result",
        cascade="all, delete-orphan",
        order_by="GameResultPlayer.id",
    )


class GameResultPlayer(Base):
    """One attendee who was on the team's roster when a :class:`GameResult` was recorded.

    This is the per-player half of the record: it is what lets an attendee's
    win/lose history be read back even after their team assignment (and the
    team itself) has since been wiped by a reshuffle — this row only ever
    disappears if the ``GameResult`` it belongs to, or the attendee, is deleted.
    """

    __tablename__ = "game_result_players"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    game_result_id: Mapped[int] = mapped_column(
        ForeignKey("game_results.id", ondelete="CASCADE"), nullable=False, index=True
    )
    attendee_id: Mapped[int] = mapped_column(
        ForeignKey("attendees.id", ondelete="CASCADE"), nullable=False, index=True
    )

    game_result: Mapped[GameResult] = relationship(back_populates="players")
    attendee: Mapped[Attendee] = relationship()


class Admin(Base):
    """A person who can operate the app — appointed only, never self-registered.

    See NEW_PROJECT_PLAN.md: exactly two roles (``super_admin`` / ``admin``),
    equal functionality across every sport, revocation via ``is_active`` (not
    row deletion, so audit-log/session history stays intact).
    """

    __tablename__ = "admins"
    __table_args__ = (
        UniqueConstraint("username", name="uq_admins_username"),
        CheckConstraint(_in_clause("role", ADMIN_ROLES), name="ck_admins_role"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(50), nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False, default="admin", server_default="admin")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=true())
    # Always true for a newly-appointed admin — forces the password-change
    # screen before anything else in the app is reachable (plan: "forced
    # password change upon login").
    must_change_password: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=true()
    )
    # Display-only labels shown as pill badges on the admin's profile card
    # (e.g. "Basketball,Volleyball"), comma-joined. Cosmetic only — NEVER
    # wired to a permission check (plan: every admin has equal rights
    # regardless of these tags).
    sport_tags: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # Brute-force lockout (security hardening, added post-launch): counts
    # consecutive failed logins, reset to 0 on any success. Once it reaches
    # security.MAX_FAILED_LOGIN_ATTEMPTS, locked_until is set and further
    # logins are rejected — even with the correct password — until it
    # passes, regardless of how many more attempts arrive.
    failed_login_attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    locked_until: Mapped[dt.datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, server_default=func.now())

    sessions: Mapped[list["AdminSession"]] = relationship(
        back_populates="admin", cascade="all, delete-orphan"
    )


class AdminSession(Base):
    """One issued login session for one admin.

    Deliberately a server-side row, not a stateless JWT: the plan's
    revocation requirement ("session ends immediately, not just can't log in
    next time") needs a token that can be killed by checking DB state on
    every request. In practice this is checked via ``Admin.is_active`` — an
    admin's every existing session dies the instant they're deactivated,
    with no need to enumerate/delete individual session rows for that case.
    """

    __tablename__ = "admin_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    admin_id: Mapped[int] = mapped_column(
        ForeignKey("admins.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # sha256 hex digest of the raw token. The raw token is sent to the client
    # exactly once, at login, and never stored — same reasoning as a hashed
    # password: a DB read alone should never hand out a live credential.
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, server_default=func.now())
    # Set on explicit logout (kills this one session without touching the
    # admin's other logged-in devices). Deactivation doesn't set this — it
    # doesn't need to, since is_active is checked directly on every request.
    revoked_at: Mapped[dt.datetime | None] = mapped_column(DateTime, nullable=True)

    admin: Mapped[Admin] = relationship(back_populates="sessions")


class AuditLogEntry(Base):
    """Append-only trail of admin-account lifecycle events.

    Deliberately minimal (plan: "just a simple audit trail") — account
    creation/revocation/reactivation, password changes, and login
    success/failure. Not a general-purpose activity log for session/roster
    actions.
    """

    __tablename__ = "audit_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    actor_admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("admins.id", ondelete="SET NULL"), nullable=True
    )
    # Snapshot so the entry still reads sensibly if the actor account is
    # later removed — same pattern as GameResult.team_name.
    actor_display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    detail: Mapped[str | None] = mapped_column(String(200), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, server_default=func.now())
