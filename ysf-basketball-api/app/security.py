"""Optional organizer authentication.

Spec Section 2 says the MVP needs no auth, and Section 9 lists organizer login
as a future consideration. This module keeps that promise while making the
future step one line of config: leave ``ORGANIZER_API_KEY`` empty and every
organizer endpoint stays open; set it and callers must send

    X-Organizer-Key: <the value>

The public check-in endpoint never uses this dependency.
"""

from __future__ import annotations

import secrets

from fastapi import Header, HTTPException, status

from app.config import settings

HEADER_NAME = "X-Organizer-Key"


def require_organizer(
    x_organizer_key: str | None = Header(default=None, alias=HEADER_NAME),
) -> None:
    """FastAPI dependency guarding organizer-only endpoints."""
    if not settings.auth_enabled:
        return

    expected = settings.organizer_api_key.strip()
    supplied = (x_organizer_key or "").strip()
    # compare_digest keeps the check constant-time.
    if not supplied or not secrets.compare_digest(supplied, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Missing or invalid {HEADER_NAME} header.",
            headers={"WWW-Authenticate": HEADER_NAME},
        )
