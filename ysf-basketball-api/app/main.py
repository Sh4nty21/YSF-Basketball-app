"""FastAPI application entry point.

Run locally with:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

Interactive docs:
    http://localhost:8000/docs
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

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
    """Used by Render/Railway health checks and by the app's connection banner."""

    database_ok = True
    error: str | None = None

    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))

    except Exception as exc:  # noqa: BLE001
        database_ok = False
        error = str(exc).splitlines()[0][:200]

    return {
        "status": "ok" if database_ok else "degraded",
        "version": __version__,
        "database": "connected" if database_ok else "unreachable",
        "auth_required": True,
        "error": error,
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