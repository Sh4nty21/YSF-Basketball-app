"""SQLAlchemy ORM models — the persistence shape of the system.

Mirrors the SQL in spec Section 4 exactly, including every CHECK constraint,
so the database rejects bad rows even if a bug ever slips past the API layer.
"""

from __future__ import annotations

import datetime as dt

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.config import (
    ADDED_VIA_VALUES,
    ATTENDEE_SOURCES,
    SESSION_STATUSES,
    SKILL_LEVELS,
    TEAM_FORMATS,
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
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_date: Mapped[dt.date] = mapped_column(Date, nullable=False)
    week_label: Mapped[str | None] = mapped_column(String(50))
    team_format: Mapped[str] = mapped_column(String(10), nullable=False)
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


class Attendee(Base):
    """A single check-in for a single session.

    Attendance is deliberately per-session: no cross-week identity matching
    (spec Section 4 note).
    """

    __tablename__ = "attendees"
    __table_args__ = (
        CheckConstraint("age > 0 AND age < 100", name="ck_attendees_age"),
        CheckConstraint(_in_clause("skill_level", SKILL_LEVELS), name="ck_attendees_skill_level"),
        CheckConstraint(_in_clause("source", ATTENDEE_SOURCES), name="ck_attendees_source"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    age: Mapped[int] = mapped_column(Integer, nullable=False)
    skill_level: Mapped[str] = mapped_column(String(20), nullable=False)
    source: Mapped[str] = mapped_column(String(10), nullable=False, default="qr", server_default="qr")
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
