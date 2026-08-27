"""Attendance statistics assembly (spec Section 5, ``GET /sessions/{id}/stats``).

Pure: it turns already-fetched counts into the response payload.
"""

from __future__ import annotations

import datetime as dt

from app.schemas import SessionStats, SkillBreakdown, SourceBreakdown


def build_stats(
    *,
    session_id: int,
    session_date: dt.date,
    week_label: str | None,
    team_format: str,
    status: str,
    skill_counts: dict[str, int],
    source_counts: dict[str, int],
    team_count: int,
    assigned_count: int,
    average_age: float | None,
) -> SessionStats:
    skills = SkillBreakdown(
        beginner=skill_counts.get("beginner", 0),
        intermediate=skill_counts.get("intermediate", 0),
    )
    sources = SourceBreakdown(
        qr=source_counts.get("qr", 0),
        manual=source_counts.get("manual", 0),
    )
    total = skills.beginner + skills.intermediate

    return SessionStats(
        session_id=session_id,
        session_date=session_date,
        week_label=week_label,
        team_format=team_format,
        status=status,
        total_attendance=total,
        skill_breakdown=skills,
        source_breakdown=sources,
        team_count=team_count,
        assigned_count=assigned_count,
        unassigned_count=max(0, total - assigned_count),
        average_age=average_age,
    )
