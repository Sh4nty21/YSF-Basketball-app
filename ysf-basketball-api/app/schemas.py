"""Pydantic schemas — the wire shape of the API (spec Section 5).

Responsibility: describe and validate what goes in and out over HTTP. These
are intentionally separate from ``app.models`` so the database shape and the
public contract can evolve independently.
"""

from __future__ import annotations

import datetime as dt
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.config import settings

SkillLevel = Literal["beginner", "intermediate"]
TeamFormat = Literal["5v5", "4v4", "3v3"]
SessionStatus = Literal["open", "closed"]
TeamResult = Literal["win", "lose"]
SportName = Literal["basketball", "volleyball", "badminton"]
AdminRole = Literal["super_admin", "admin"]
VolleyballPosition = Literal["outside_hitter", "middle_blocker", "setter", "opposite"]
BadmintonMode = Literal["singles", "doubles"]

# Trimmed, non-empty, at most the column width.
NonEmptyName = Annotated[str, Field(min_length=1, max_length=100)]


class _Base(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ── Sessions ──────────────────────────────────────────────────────────────


class SessionCreate(_Base):
    session_date: dt.date
    week_label: str | None = Field(default=None, max_length=50)
    sport: SportName = "basketball"
    # Required for basketball (5v5/4v4/3v3); left null for volleyball/
    # badminton, which don't use this concept — see NEW_PROJECT_PLAN.md.
    team_format: TeamFormat | None = None
    # Required for badminton (Singles or Doubles); null for every other sport.
    badminton_mode: BadmintonMode | None = None

    @field_validator("week_label")
    @classmethod
    def _blank_label_is_none(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None

    @model_validator(mode="after")
    def _sport_specific_fields_required(self) -> "SessionCreate":
        if self.sport == "basketball" and self.team_format is None:
            raise ValueError("team_format is required for basketball sessions")
        if self.sport == "badminton" and self.badminton_mode is None:
            raise ValueError("badminton_mode is required for badminton sessions")
        return self


class SessionUpdate(_Base):
    """PATCH body. All fields optional; at least one must be supplied."""

    team_format: TeamFormat | None = None
    badminton_mode: BadmintonMode | None = None
    status: SessionStatus | None = None
    week_label: str | None = Field(default=None, max_length=50)


class SessionRead(_Base):
    id: int
    session_date: dt.date
    week_label: str | None
    sport: SportName
    team_format: TeamFormat | None
    badminton_mode: BadmintonMode | None
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
    # Required for basketball/badminton, must be omitted for volleyball —
    # enforced per-session (not here, since this schema has no way to know
    # which session/sport it's for) by
    # `app.services.attendee_validation.validate_attendee_for_sport`.
    skill_level: SkillLevel | None = None
    # Volleyball only — one of the 4 positions, in place of skill_level.
    position: VolleyballPosition | None = None
    # Client-generated, persisted in the browser's localStorage. Required by
    # the public checkin router (not by organizer manual-add) so the same
    # device can't be used to flood a session with fake registrations.
    device_id: str | None = Field(default=None, max_length=64)

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

    @field_validator("device_id")
    @classmethod
    def _blank_device_id_is_none(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None


class AttendeeRead(_Base):
    id: int
    session_id: int
    name: str
    age: int
    skill_level: SkillLevel | None
    position: VolleyballPosition | None = None
    source: Literal["qr", "manual"]
    checked_in_at: dt.datetime | None
    # Null when the attendee has not been placed on a team yet.
    team_id: int | None = None
    team_name: str | None = None
    # "manual-add" here means this attendee arrived after teams already
    # existed and was auto-slotted in (or added via /teams/add-player) — the
    # app labels this "Late registration". "generate" means they were part
    # of the original draft. Null alongside team_id/team_name = unplaced.
    added_via: Literal["generate", "manual-add"] | None = None
    # Aggregated across every game_results row this attendee was on the
    # roster for, this session — survives every reshuffle, since regenerate
    # never touches attendees or game_results (spec: individual tracking).
    wins: int = 0
    losses: int = 0


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
    skill_level: SkillLevel | None
    position: VolleyballPosition | None = None
    added_via: Literal["generate", "manual-add"]
    # Same session-wide, reshuffle-surviving tally as AttendeeRead.wins/losses
    # — shown here too so a roster card doesn't need a second request.
    wins: int = 0
    losses: int = 0


class TeamRead(_Base):
    team_id: int
    team_name: str
    members: list[TeamMemberRead]


class TeamsResponse(_Base):
    session_id: int
    team_format: TeamFormat | None
    teams: list[TeamRead]
    unassigned: list[AttendeeRead] = Field(
        default_factory=list,
        description="Attendees checked in but not yet on a team (late arrivals).",
    )


class AddPlayerRequest(_Base):
    attendee_id: int


# ── Game results (win/lose record system) ───────────────────────────────────


class GameResultCreate(_Base):
    """Body for ``POST /teams/{team_id}/results``. Always creates a new row —
    a team plays more than once a session, so there is no "update", only
    "record another one". Mistakes are corrected via the delete endpoint."""

    result: TeamResult


class GameResultPlayerRead(_Base):
    attendee_id: int
    name: str


class GameResultRead(_Base):
    id: int
    session_id: int
    # Null if the team that earned this result was later deleted by a
    # reshuffle — team_name below is what keeps the record legible regardless.
    team_id: int | None
    team_name: str
    result: TeamResult
    recorded_at: dt.datetime | None
    players: list[GameResultPlayerRead]


# ── Stats ─────────────────────────────────────────────────────────────────


class SkillBreakdown(_Base):
    beginner: int = 0
    intermediate: int = 0


class SourceBreakdown(_Base):
    qr: int = 0
    manual: int = 0


class SessionStats(_Base):
    session_id: int
    session_date: dt.date
    week_label: str | None
    team_format: TeamFormat | None
    status: SessionStatus
    total_attendance: int
    skill_breakdown: SkillBreakdown
    source_breakdown: SourceBreakdown
    team_count: int
    assigned_count: int
    unassigned_count: int
    average_age: float | None


# ── Admin accounts (NEW_PROJECT_PLAN.md) ─────────────────────────────────


NonEmptyUsername = Annotated[str, Field(min_length=3, max_length=50)]
NonEmptyDisplayName = Annotated[str, Field(min_length=1, max_length=100)]
Password = Annotated[str, Field(min_length=8, max_length=100)]


class AdminCreate(_Base):
    """Body for ``POST /admins`` — super-admin-only. No self-registration
    route exists anywhere; this is the only way an admin account is made."""

    username: NonEmptyUsername
    display_name: NonEmptyDisplayName
    password: Password
    role: AdminRole = "admin"
    # Display-only labels for the profile card (e.g. ["Basketball",
    # "Volleyball"]) — cosmetic, never used for access control.
    sport_tags: list[str] = Field(default_factory=list)

    @field_validator("username")
    @classmethod
    def _normalise_username(cls, value: str) -> str:
        cleaned = value.strip().lower()
        if not cleaned:
            raise ValueError("username must not be empty")
        return cleaned

    @field_validator("display_name")
    @classmethod
    def _strip_display_name(cls, value: str) -> str:
        cleaned = " ".join(value.split())
        if not cleaned:
            raise ValueError("display_name must not be empty")
        return cleaned


class AdminRead(_Base):
    id: int
    username: str
    # "Coach" display convention (NEW_PROJECT_PLAN.md) is applied by the
    # client at render time, not stored here — this is the plain name.
    display_name: str
    role: AdminRole
    is_active: bool
    must_change_password: bool
    sport_tags: list[str] = Field(default_factory=list)
    created_at: dt.datetime | None


class AdminStatusUpdate(_Base):
    """Body for ``PATCH /admins/{id}`` — revoke or reactivate."""

    is_active: bool


class LoginRequest(_Base):
    username: str
    password: str


class LoginResponse(_Base):
    token: str
    admin: AdminRead


class ChangePasswordRequest(_Base):
    current_password: str
    new_password: Password


class AuditLogEntryRead(_Base):
    id: int
    actor_display_name: str
    action: str
    detail: str | None
    created_at: dt.datetime | None


# ── Errors ────────────────────────────────────────────────────────────────


class ErrorResponse(_Base):
    detail: str
