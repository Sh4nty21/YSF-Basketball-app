"""FastAPI application entry point.

Run locally with:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Interactive docs:
    http://localhost:8000/docs
"""

from __future__ import annotations

import logging
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

logger = logging.getLogger(__name__)

from app import __version__
from app.config import settings
from app.database import SessionLocal, engine
from app.repositories import admins_repo
from app.routers import admin_auth, admins, attendees, checkin, results, sessions, stats, teams
from app.security import hash_password


DESCRIPTION = """
Backend for the **Elevate YSF** weekly sports fellowship.

* `POST /api/v1/sessions/{id}/checkin` is **public** — it is what the QR-code
  web form calls.
* Every other endpoint requires an admin session: `POST /api/v1/auth/login`
  with a username/password, then send the returned token as
  `Authorization: Bearer <token>`. Accounts are appointed only — there is no
  public registration route; see `BOOTSTRAP_ADMIN_USERNAME` /
  `BOOTSTRAP_ADMIN_PASSWORD` for how the very first super-admin is created.

All team-balancing logic lives here, never in the app or the web form.
"""


app = FastAPI(
    title=settings.app_name,
    version=__version__,
    description=DESCRIPTION,
    docs_url="/docs",
    redoc_url=None,
)


# ─────────────────────────────────────────────────────────────────────────────
# CORS
# ─────────────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# API ROUTERS
# ─────────────────────────────────────────────────────────────────────────────

for router in (
    admin_auth.router,
    admins.router,
    sessions.router,
    checkin.router,
    attendees.router,
    teams.router,
    results.router,
    stats.router,
):
    app.include_router(router, prefix=settings.api_prefix)


# ─────────────────────────────────────────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────────────────────────────────────────

@app.get(
    "/health",
    tags=["meta"],
    summary="Liveness + database probe",
)
def health() -> dict:
    """Used by Render/Railway health checks and by the app's connection banner.

    Public and unauthenticated by design (it has to be, for hosting-platform
    health probes) — so it must never echo the raw exception back. A
    database connection error can embed the connection string, including
    the password, depending on the driver/failure mode; the full error is
    logged server-side instead, where only whoever has log access can see
    it, and the public response gets a fixed, generic message.
    """

    database_ok = True

    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))

    except Exception:  # noqa: BLE001
        database_ok = False
        logger.exception("Health check: database connection failed")

    return {
        "status": "ok" if database_ok else "degraded",
        "version": __version__,
        "database": "connected" if database_ok else "unreachable",
        "auth_required": True,
        "error": None if database_ok else "Database is unreachable. See server logs for detail.",
    }


# ─────────────────────────────────────────────────────────────────────────────
# BOOTSTRAP THE FIRST SUPER-ADMIN
# ─────────────────────────────────────────────────────────────────────────────


@app.on_event("startup")
def bootstrap_first_super_admin() -> None:
    """Create exactly one super-admin from env vars, but only while the
    admins table is still empty.

    There is no public registration route, and every other way to create an
    admin account requires an existing super-admin — so without this, a
    fresh deployment would have no way to ever create its first account.
    Safe to leave ``BOOTSTRAP_ADMIN_USERNAME`` / ``BOOTSTRAP_ADMIN_PASSWORD``
    set permanently: this is a no-op on every startup after the first.
    """
    if not settings.bootstrap_admin_username or not settings.bootstrap_admin_password:
        return

    db = SessionLocal()
    try:
        if admins_repo.list_all(db):
            return
        admin = admins_repo.create(
            db,
            username=settings.bootstrap_admin_username.strip().lower(),
            display_name="Main Fellowship Admin",
            password_hash=hash_password(settings.bootstrap_admin_password),
            role="super_admin",
            sport_tags=None,
        )
        admins_repo.log(
            db,
            actor=None,
            actor_display_name=admin.display_name,
            action="admin_created",
            detail="bootstrap account created at startup",
        )
    finally:
        db.close()


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC CHECK-IN WEBSITE
# ─────────────────────────────────────────────────────────────────────────────
#
# Dockerfile copies:
#
# /app/ysf-basketball-api/
# /app/ysf-basketball-checkin/
#
# main.py lives at:
#
# /app/ysf-basketball-api/app/main.py
#
# Therefore parents[2] points to:
#
# /app
#
# and the check-in directory is:
#
# /app/ysf-basketball-checkin
#
# ─────────────────────────────────────────────────────────────────────────────

_CHECKIN_DIR = (
    Path(__file__).resolve().parents[2] / "ysf-basketball-checkin"
)


class NoCacheStaticFiles(StaticFiles):
    """Forces revalidation on every request instead of letting browsers use
    their own (often long-lived) heuristic caching for these files.

    Still cheap: the ETag/Last-Modified headers StaticFiles already sets let
    a revalidation come back as a 304 with no body when nothing changed —
    this only stops a phone from serving a stale app.js/styles.css without
    even asking the server, which is what let a bug fix here go unnoticed by
    someone who had already loaded the check-in page once before the deploy.
    """

    async def get_response(self, path: str, scope):  # type: ignore[override]
        response = await super().get_response(path, scope)
        response.headers["Cache-Control"] = "no-cache"
        return response


# ─────────────────────────────────────────────────────────────────────────────
# ADMIN APP (Flutter web build)
# ─────────────────────────────────────────────────────────────────────────────
#
# The organizer app has no deploy pipeline of its own — Render's build step
# has no Flutter SDK, so this is the checked-in output of
# `flutter build web --base-href /admin/` (ysf_basketball_app/build/web/),
# regenerated and re-committed by hand whenever the app changes (see the
# .gitignore exception in ysf_basketball_app/ for why this directory is
# committed at all despite /build/ being ignored everywhere else).
#
# Mounted BEFORE the check-in form's catch-all "/" mount below — Starlette
# matches mounts in registration order, and "/" would otherwise swallow
# every "/admin/..." request before this one ever got a chance.
# ─────────────────────────────────────────────────────────────────────────────

_ADMIN_APP_DIR = (
    Path(__file__).resolve().parents[2] / "ysf_basketball_app" / "build" / "web"
)

if _ADMIN_APP_DIR.is_dir():

    # A bare "/admin" (no trailing slash) doesn't match the mount below —
    # Starlette's Mount only matches "/admin/..." — so without this it 404s,
    # which is exactly the URL shape someone would naturally type or share.
    @app.get("/admin", include_in_schema=False)
    def _admin_app_redirect() -> RedirectResponse:
        return RedirectResponse(url="/admin/")

    app.mount(
        "/admin",
        StaticFiles(directory=str(_ADMIN_APP_DIR), html=True),
        name="admin-app",
    )


if _CHECKIN_DIR.is_dir():

    # Serve the public check-in website at the ROOT of the Render service.
    #
    # Therefore:
    #
    # https://ysf-basketball-app.onrender.com/
    #
    # opens the check-in page.
    #
    # And:
    #
    # https://ysf-basketball-app.onrender.com/?session=1
    #
    # opens the check-in page for session 1.
    #
    # The API still works because the API routes were registered above
    # this catch-all static mount.
    app.mount(
        "/",
        NoCacheStaticFiles(
            directory=str(_CHECKIN_DIR),
            html=True,
        ),
        name="checkin-form",
    )