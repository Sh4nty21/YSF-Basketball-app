"""Admin-account management — ``/admins`` — super-admin only.

No public registration route exists anywhere in this API; this router is the
only way an admin account is ever created, per NEW_PROJECT_PLAN.md.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.models import Admin
from app.presenters import (
    admin_to_schema,
    audit_log_entry_to_schema,
    sport_tags_to_column,
)
from app.repositories import admins_repo
from app.schemas import AdminCreate, AdminRead, AdminStatusUpdate, AuditLogEntryRead
from app.security import hash_password, require_super_admin

router = APIRouter(
    prefix="/admins",
    tags=["admins"],
    dependencies=[Depends(require_super_admin)],
)


@router.post("", response_model=AdminRead, status_code=status.HTTP_201_CREATED)
def create_admin(
    payload: AdminCreate,
    current_admin: Admin = Depends(require_super_admin),
    db: DbSession = Depends(get_db),
) -> AdminRead:
    """Appoint a new admin. Sets an initial username + password directly —
    no invite link, no email step. ``must_change_password`` starts ``True``,
    forcing them into the password-change screen on their first login."""
    if admins_repo.get_by_username(db, payload.username) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Username '{payload.username}' is already taken.",
        )

    admin = admins_repo.create(
        db,
        username=payload.username,
        display_name=payload.display_name,
        password_hash=hash_password(payload.password),
        role=payload.role,
        sport_tags=sport_tags_to_column(payload.sport_tags),
    )
    admins_repo.log(
        db,
        actor=current_admin,
        actor_display_name=current_admin.display_name,
        action="admin_created",
        detail=f"created '{admin.username}' ({admin.role})",
    )
    return admin_to_schema(admin)


@router.get("", response_model=list[AdminRead])
def list_admins(db: DbSession = Depends(get_db)) -> list[AdminRead]:
    return [admin_to_schema(admin) for admin in admins_repo.list_all(db)]


@router.patch("/{admin_id}", response_model=AdminRead)
def update_admin_status(
    admin_id: int,
    payload: AdminStatusUpdate,
    current_admin: Admin = Depends(require_super_admin),
    db: DbSession = Depends(get_db),
) -> AdminRead:
    """Revoke or reactivate. Revoking is an immediate, hard cutoff: the
    admin's ``is_active`` flag is checked on every subsequent request, so
    their current session dies on their very next call — see
    ``security.get_current_session``."""
    admin = admins_repo.get(db, admin_id)
    if admin is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Admin {admin_id} was not found."
        )
    if admin.id == current_admin.id and not payload.is_active:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You cannot revoke your own account.",
        )

    updated = admins_repo.set_active(db, admin, payload.is_active)
    admins_repo.log(
        db,
        actor=current_admin,
        actor_display_name=current_admin.display_name,
        action="admin_revoked" if not payload.is_active else "admin_reactivated",
        detail=f"target '{updated.username}'",
    )
    return admin_to_schema(updated)


@router.get("/audit-log", response_model=list[AuditLogEntryRead])
def get_audit_log(
    limit: int = 100, offset: int = 0, db: DbSession = Depends(get_db)
) -> list[AuditLogEntryRead]:
    entries = admins_repo.list_audit_log(db, limit=limit, offset=offset)
    return [audit_log_entry_to_schema(entry) for entry in entries]
