"""Admin login/logout/password-change — ``/auth/...``.

``POST /auth/login`` is the one auth endpoint reachable without a session
token already (mirrors how ``checkin.py`` is the one public exception among
organizer endpoints). Everything else here requires a valid session.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as DbSession

from app.database import get_db
from app.models import Admin, AdminSession
from app.presenters import admin_to_schema
from app.repositories import admins_repo
from app.schemas import AdminRead, ChangePasswordRequest, LoginRequest, LoginResponse
from app.security import (
    generate_session_token,
    get_current_admin,
    get_current_session,
    hash_password,
    hash_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: DbSession = Depends(get_db)) -> LoginResponse:
    admin = admins_repo.get_by_username(db, payload.username.strip().lower())

    invalid = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect username or password.",
    )

    if admin is None or not verify_password(payload.password, admin.password_hash):
        admins_repo.log(
            db,
            actor=None,
            actor_display_name=payload.username.strip() or "(unknown)",
            action="login_failed",
            detail="incorrect username or password",
        )
        raise invalid

    if not admin.is_active:
        admins_repo.log(
            db,
            actor=admin,
            actor_display_name=admin.display_name,
            action="login_failed",
            detail="account is deactivated",
        )
        raise invalid

    token = generate_session_token()
    admins_repo.create_session(db, admin, hash_token(token))
    admins_repo.log(
        db, actor=admin, actor_display_name=admin.display_name, action="login_succeeded"
    )

    return LoginResponse(token=token, admin=admin_to_schema(admin))


@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(
    session_row: AdminSession = Depends(get_current_session),
    db: DbSession = Depends(get_db),
) -> dict[str, str]:
    """Ends only *this* session — other devices this admin is logged into
    keep working, unlike a super-admin deactivating the whole account."""
    admins_repo.revoke_session(db, session_row)
    return {"message": "Logged out."}


@router.get("/me", response_model=AdminRead)
def me(admin: Admin = Depends(get_current_admin)) -> AdminRead:
    """Lets the app confirm who's signed in and whether a forced password
    change is still pending, without decoding anything client-side."""
    return admin_to_schema(admin)


@router.post("/change-password", response_model=AdminRead)
def change_password(
    payload: ChangePasswordRequest,
    admin: Admin = Depends(get_current_admin),
    db: DbSession = Depends(get_db),
) -> AdminRead:
    """Also clears ``must_change_password`` — this is the screen that gate
    satisfies, whether it's the forced first-login change or a voluntary one."""
    if not verify_password(payload.current_password, admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Current password is incorrect.",
        )

    updated = admins_repo.set_password(
        db, admin, hash_password(payload.new_password), must_change_password=False
    )
    admins_repo.log(
        db, actor=updated, actor_display_name=updated.display_name, action="password_changed"
    )
    return admin_to_schema(updated)
