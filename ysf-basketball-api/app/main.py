"""FastAPI application entry point.

Run locally with:  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
Interactive docs:  http://localhost:8000/docs
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app import __version__
from app.config import settings
from app.database import engine
from app.routers import attendees, checkin, sessions, stats, teams

DESCRIPTION = """
Backend for the **Elevate YSF** weekly basketball fellowship.

* `POST /api/v1/sessions/{id}/checkin` is **public** — it is what the QR-code
  web form calls.
* Every other endpoint is organizer-facing. If `ORGANIZER_API_KEY` is set on
  the server, send it as an `X-Organizer-Key` header.

All team-balancing logic lives here, never in the app or the web form.
"""

app = FastAPI(
    title=settings.app_name,
    version=__version__,
    description=DESCRIPTION,
    docs_url="/docs",
    redoc_url=None,
)

# The check-in form runs in a browser on a different origin, so CORS matters.
# Flutter on Android/iOS is unaffected, but Flutter Web during testing is not.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

for router in (sessions.router, checkin.router, attendees.router, teams.router, stats.router):
    app.include_router(router, prefix=settings.api_prefix)


@app.get("/health", tags=["meta"], summary="Liveness + database probe")
def health() -> dict:
    """Used by Render/Railway health checks and by the app's connection banner."""
    database_ok = True
    error: str | None = None
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001 - report any driver/network failure
        database_ok = False
        error = str(exc).splitlines()[0][:200]

    return {
        "status": "ok" if database_ok else "degraded",
        "version": __version__,
        "database": "connected" if database_ok else "unreachable",
        "auth_required": settings.auth_enabled,
        "error": error,
    }


@app.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse(url="/docs")


# ── Optional: serve the public check-in form from this same process ─────────
# Module B stays a separate, independently testable folder (spec Section 3).
# Mounting it here is purely hosting convenience: one deployment then serves
# both the API and the page participants scan into, so nothing on the
# organizer's own laptop has to stay switched on.
_CHECKIN_DIR = Path(__file__).resolve().parents[2] / "ysf-basketball-checkin"
if _CHECKIN_DIR.is_dir():
    app.mount(
        "/checkin",
        StaticFiles(directory=str(_CHECKIN_DIR), html=True),
        name="checkin-form",
    )
