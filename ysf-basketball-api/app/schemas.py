"""Pydantic schemas — the wire shape of the API (spec Section 5).

Responsibility: describe and validate what goes in and out over HTTP. These
are intentionally separate from ``app.models`` so the database shape and the
public contract can evolve independently.
"""

from __future__ import annotations

import datetime as dt
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.config import settings

SkillLevel = Literal["beginner", "intermediate", "pro"]
TeamFormat = Literal["5v5", "4v4", "3v3"]
SessionStatus = Literal["open", "closed"]

# Trimmed, non-empty, at most the column width.
NonEmptyName = Annotated[str, Field(min_length=1, max_length=100)]


class _Base(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ── Sessions ──────────────────────────────────────────────────────────────


class SessionCreate(_Base):
    session_date: dt.date
    week_label: str | None = Field(default=None, max_length=50)
    team_format: TeamFormat

    @field_validator("week_label")
    @classmethod
    def _blank_label_is_none(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None


class SessionUpdate(_Base):
    """PATCH body. Both fields optional; at least one must be supplied."""

    team_format: TeamFormat | None = None
    status: SessionStatus | None = None
    week_label: str | None = Field(default=None, max_length=50)


class SessionRead(_Base):
    id: int
    session_date: dt.date
    week_label: str | None
    team_format: TeamFormat
    status: SessionStatus
    created_at: dt.datetime | None
    # Convenience fields so list/dashboard screens need only one request.
    attendee_count: int = 0
    team_count: int = 0
    checkin_url: str = ""


# ── Attendees ─────────────────────────────────────────────────────────────


class AttendeeCreate(_Base):
    """Body for both ``POST /checkin`` (public) and ``POST /attendees``.

    ``source`` is decided by the endpoint, never by the client, so it is not
    part of this schema.
    """

    name: NonEmptyName
    age: int
    skill_level: SkillLevel

    @field_validator("name")
    @classmethod
    def _strip_name(cls, value: str) -> str:
        cleaned = " ".join(value.split())
        if not cleaned:
            raise ValueError("name must not be empty")
        return cleaned

    @field_validator("age")
    @classmethod
    def _age_in_range(cls, value: int) -> int:
        if not settings.min_age <= value <= settings.max_age:
            raise ValueError(
                f"age must be between {settings.min_age} and {settings.max_age}"
            )
        return value


class AttendeeRead(_Base):
    id: int
    session_id: int
    name: str
    age: int
    skill_level: SkillLevel
    source: Literal["qr", "manual"]
    checked_in_at: dt.datetime | None
    # Null when the attendee has not been placed on a team yet.
    team_id: int | None = None
    team_name: str | None = None


class CheckinResponse(_Base):
    """Deliberately minimal: the public form must not leak the roster."""

    attendee_id: int
    name: str
    message: str


# ── Teams ─────────────────────────────────────────────────────────────────


class TeamMemberRead(_Base):
    attendee_id: int
    name: str
    age: int
    skill_level: SkillLevel
    added_via: Literal["generate", "manual-add"]


class TeamRead(_Base):
    team_id: int
    team_name: str
    members: list[TeamMemberRead]


class TeamsResponse(_Base):
    session_id: int
    team_format: TeamFormat
    teams: list[TeamRead]
    unassigned: list[AttendeeRead] = Field(
        default_factory=list,
        description="Attendees checked in but not yet on a team (late arrivals).",
    )


class AddPlayerRequest(_Base):
    attendee_id: int


# ── Stats ─────────────────────────────────────────────────────────────────


class SkillBreakdown(_Base):
    beginner: int = 0
    intermediate: int = 0
    pro: int = 0


class SourceBreakdown(_Base):
    qr: int = 0
    manual: int = 0


class SessionStats(_Base):
    session_id: int
    session_date: dt.date
    week_label: str | None
    team_format: TeamFormat
    status: SessionStatus
    total_attendance: int
    skill_breakdown: SkillBreakdown
    source_breakdown: SourceBreakdown
    team_count: int
    assigned_count: int
    unassigned_count: int
    average_age: float | None


# ── Errors ────────────────────────────────────────────────────────────────


class ErrorResponse(_Base):
    detail: str
