-- ═══════════════════════════════════════════════════════════════════════════
--  YSF Basketball — schema (spec Section 4)
--
--  ESCAPE HATCH ONLY. The supported way to create these tables is:
--      alembic upgrade head
--
--  Use this file if you would rather click than type: open your Supabase
--  project -> SQL Editor -> New query -> paste -> Run. Afterwards run
--      alembic stamp head
--  so Alembic knows the schema already exists and future migrations apply
--  cleanly on top.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS sessions (
    id          SERIAL PRIMARY KEY,
    session_date DATE NOT NULL,
    week_label  VARCHAR(50),
    team_format VARCHAR(10) NOT NULL CHECK (team_format IN ('5v5','4v4','3v3')),
    status      VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Attendance is per-session only: no cross-week identity matching.
CREATE TABLE IF NOT EXISTS attendees (
    id            SERIAL PRIMARY KEY,
    session_id    INT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    name          VARCHAR(100) NOT NULL,
    age           INT NOT NULL CHECK (age > 0 AND age < 100),
    skill_level   VARCHAR(20) NOT NULL CHECK (skill_level IN ('beginner','intermediate','pro')),
    source        VARCHAR(10) NOT NULL DEFAULT 'qr' CHECK (source IN ('qr','manual')),
    checked_in_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_attendees_session_id ON attendees(session_id);

CREATE TABLE IF NOT EXISTS teams (
    id         SERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    team_name  VARCHAR(50) NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_teams_session_id ON teams(session_id);

CREATE TABLE IF NOT EXISTS team_members (
    id          SERIAL PRIMARY KEY,
    team_id     INT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    attendee_id INT NOT NULL REFERENCES attendees(id) ON DELETE CASCADE,
    added_via   VARCHAR(20) NOT NULL DEFAULT 'generate' CHECK (added_via IN ('generate','manual-add')),
    added_at    TIMESTAMP DEFAULT NOW(),
    CONSTRAINT uq_team_members_attendee UNIQUE (attendee_id)
);
CREATE INDEX IF NOT EXISTS ix_team_members_team_id ON team_members(team_id);

-- ── Note on Supabase Row Level Security ────────────────────────────────────
-- These tables are reached only through the FastAPI backend using the Postgres
-- connection string, which bypasses RLS. Do NOT expose them through Supabase's
-- auto-generated REST/anon API: that would let a browser edit rosters directly
-- and bypass every rule in the backend. Leaving RLS enabled with no policies
-- (Supabase's default for new tables created via the dashboard) is exactly
-- what you want here.
