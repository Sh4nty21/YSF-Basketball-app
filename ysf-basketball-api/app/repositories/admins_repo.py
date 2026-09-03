"""Queries for ``admins``, ``admin_sessions``, and ``audit_log``.

Split into one module rather than three since each table is small and the
three are only ever touched together (an admin action almost always writes
an audit-log row in the same request).
"""

from __future__ import annotations

import datetime as dt

from sqlalchemy import select
from sqlalchemy.orm import Session as DbSession

from app.models import Admin, AdminSession, AuditLogEntry


# ── admins ────────────────────────────────────────────────────────────────


def get(db: DbSession, admin_id: int) -> Admin | None:
    return db.get(Admin, admin_id)


def get_by_username(db: DbSession, username: str) -> Admin | None:
    return db.scalar(select(Admin).where(Admin.username == username))


def list_all(db: DbSession) -> list[Admin]:
    """Every admin account, most recently created first."""
    stmt = select(Admin).order_by(Admin.created_at.desc(), Admin.id.desc())
    return list(db.scalars(stmt))


def create(
    db: DbSession,
    *,
    username: str,
    display_name: str,
    password_hash: str,
    role: str,
    sport_tags: str | None,
) -> Admin:
    admin = Admin(
        username=username,
        display_name=display_name,
        password_hash=password_hash,
        role=role,
        is_active=True,
        must_change_password=True,
        sport_tags=sport_tags,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


def set_active(db: DbSession, admin: Admin, is_active: bool) -> Admin:
    admin.is_active = is_active
    db.commit()
    db.refresh(admin)
    return admin


def set_password(db: DbSession, admin: Admin, password_hash: str, must_change_password: bool) -> Admin:
    admin.password_hash = password_hash
    admin.must_change_password = must_change_password
    db.commit()
    db.refresh(admin)
    return admin


# ── admin sessions ───────────────────────────────────────────────────────


def create_session(db: DbSession, admin: Admin, token_hash: str) -> AdminSession:
    row = AdminSession(admin_id=admin.id, token_hash=token_hash)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def get_session_by_token_hash(db: DbSession, token_hash: str) -> AdminSession | None:
    return db.scalar(select(AdminSession).where(AdminSession.token_hash == token_hash))


def revoke_session(db: DbSession, session_row: AdminSession) -> None:
    session_row.revoked_at = dt.datetime.utcnow()
    db.commit()


# ── audit log ─────────────────────────────────────────────────────────────


def log(
    db: DbSession,
    *,
    actor: Admin | None,
    actor_display_name: str,
    action: str,
    detail: str | None = None,
) -> AuditLogEntry:
    entry = AuditLogEntry(
        actor_admin_id=actor.id if actor is not None else None,
        actor_display_name=actor_display_name,
        action=action,
        detail=detail,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


def list_audit_log(db: DbSession, limit: int = 100, offset: int = 0) -> list[AuditLogEntry]:
    """Most recent first."""
    stmt = (
        select(AuditLogEntry)
        .order_by(AuditLogEntry.created_at.desc(), AuditLogEntry.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(db.scalars(stmt))
