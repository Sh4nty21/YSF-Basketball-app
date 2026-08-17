"""ORM -> response-schema conversion.

Keeps routers thin: they fetch via repositories and hand the rows here. This is
"how data is shaped for transport", not "what the data should be", so it is
deliberately free of any decision-making.
"""

from __future__ import annotations

from app.config import settings
from app.models import Attendee, Session, Team
from app.repositories import attendees_repo
from app.schemas import (
    AttendeeRead,
    SessionRead,
    TeamMemberRead,
    TeamRead,
    TeamsResponse,
)


def session_to_schema(
    session: Session,
    attendee_count: int = 0,
    team_count: int = 0,
) -> SessionRead:
    return SessionRead(
        id=session.id,
        session_date=session.session_date,
        week_label=session.week_label,
        team_format=session.team_format,
        status=session.status,
        created_at=session.created_at,
        attendee_count=attendee_count,
        team_count=team_count,
        checkin_url=settings.checkin_url_for(session.id),
    )


def attendee_to_schema(attendee: Attendee) -> AttendeeRead:
    team_id, team_name = attendees_repo.team_placement(attendee)
    return AttendeeRead(
        id=attendee.id,
        session_id=attendee.session_id,
        name=attendee.name,
        age=attendee.age,
        skill_level=attendee.skill_level,
        source=attendee.source,
        checked_in_at=attendee.checked_in_at,
        team_id=team_id,
        team_name=team_name,
    )


def team_to_schema(team: Team) -> TeamRead:
    members = [
        TeamMemberRead(
            attendee_id=member.attendee.id,
            name=member.attendee.name,
            age=member.attendee.age,
            skill_level=member.attendee.skill_level,
            added_via=member.added_via,
        )
        for member in team.members
        if member.attendee is not None
    ]
    return TeamRead(team_id=team.id, team_name=team.team_name, members=members)


def teams_to_schema(
    session: Session,
    teams: list[Team],
    unassigned: list[Attendee],
) -> TeamsResponse:
    return TeamsResponse(
        session_id=session.id,
        team_format=session.team_format,
        teams=[team_to_schema(team) for team in teams],
        unassigned=[attendee_to_schema(attendee) for attendee in unassigned],
    )
