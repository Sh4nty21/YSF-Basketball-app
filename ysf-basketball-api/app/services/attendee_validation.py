"""Sport-conditional requirements for a check-in payload.

Not enforceable at the Pydantic schema layer alone: `AttendeeCreate` has no
way to know which session (and therefore which sport) it belongs to — the
session is only resolved once a router has looked up `{session_id}`. Shared
by both `checkin.py` (public) and `attendees.py` (organizer manual-add) so
the rule lives in exactly one place.
"""

from __future__ import annotations

from app.schemas import AttendeeCreate


def validate_attendee_for_sport(sport: str, payload: AttendeeCreate) -> str | None:
    """Returns an error message if the payload is missing what this sport
    requires, or ``None`` if it's fine.

    Volleyball collects a position instead of a skill level (skill is
    deliberately unused for volleyball team generation — NEW_PROJECT_PLAN.md).
    Basketball and badminton both still key off skill level.
    """
    if sport == "volleyball":
        if payload.position is None:
            return "position is required for volleyball check-ins."
    else:
        if payload.skill_level is None:
            return "skill_level is required for this sport."
    return None
