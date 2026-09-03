"""Admin-account authentication.

Replaces the old single shared ``ORGANIZER_API_KEY`` passcode (see git
history / PROJECT_CONTEXT.md) with real per-person admin accounts, per
NEW_PROJECT_PLAN.md: appointed-only (no public registration route exists
anywhere), server-side session tokens rather than stateless JWTs (so that
revoking an admin ends their session immediately, not just "can't log in
next time"), and exactly two roles — ``super_admin`` can manage other admin
accounts, ``admin`` has full, equal functionality across every sport.

Callers send:

    Authorization: Bearer <token>

``token`` is the raw value returned once by ``POST /auth/login`` — the
database only ever stores its sha256 hash, the same reasoning as hashing a
password: a DB read alone should never hand out a live credential.
"""

from __future__ import annotations

import hashlib
import secrets

import bcrypt
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.models import Admin, AdminSession
from app.repositories import admins_repo

BEARER_PREFIX = "Bearer "


# ── passwords ────────────────────────────────────────────────────────────


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        # Malformed/foreign hash format — never let this crash the request,
        # just treat it as a failed verification.
        return False


# ── session tokens ───────────────────────────────────────────────────────


def generate_session_token() -> str:
    """A high-entropy, URL-safe raw token — this is what the client stores."""
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    """sha256 hex digest — what actually gets persisted in ``admin_sessions``."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization or not authorization.startswith(BEARER_PREFIX):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization[len(BEARER_PREFIX) :].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token


def get_current_session(
    authorization: str | None = Header(default=None),
    db: DbSession = Depends(get_db),
) -> AdminSession:
    """Resolve the calling admin's session row from their token, or 401.

    Checking ``Admin.is_active`` here (rather than only whether the token row
    exists) is what makes revocation immediate: a deactivated admin's tokens
    are still in the table, but every request they make dies right here on
    the very next call, with no need to enumerate and delete their sessions.

    Exposed separately from :func:`get_current_admin` so ``POST /auth/logout``
    can revoke *this specific* session row without affecting the admin's
    other logged-in devices.
    """
    token = _extract_bearer_token(authorization)
    session_row = admins_repo.get_session_by_token_hash(db, hash_token(token))

    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Session is invalid or has been revoked. Please log in again.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if session_row is None or session_row.revoked_at is not None:
        raise unauthorized

    admin = session_row.admin
    if admin is None or not admin.is_active:
        raise unauthorized

    return session_row


def get_current_admin(session_row: AdminSession = Depends(get_current_session)) -> Admin:
    return session_row.admin


def require_admin(admin: Admin = Depends(get_current_admin)) -> Admin:
    """Any active admin — both roles. Use as a router-level dependency."""
    return admin


def require_super_admin(admin: Admin = Depends(get_current_admin)) -> Admin:
    """Only the super-admin role — account management endpoints."""
    if admin.role != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Super-admin access required.",
        )
    return admin
