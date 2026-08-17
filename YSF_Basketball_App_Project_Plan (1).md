# YSF Basketball App — Full Project Specification

**Project Name:** YSF Basketball App
**Purpose:** A roster/team organizer system for a weekly youth sports fellowship basketball program.
**Audience for this document:** An AI coding agent executing this project locally, and a human project owner who is new to mobile app development.

---

## 1. PROJECT OVERVIEW

The system has three components:

1. **Backend API** — Python (FastAPI) + PostgreSQL. Handles all data storage, business logic, and team-balancing algorithm. This is the single source of truth. Both the web form and the Flutter app talk to this backend only — they never talk to the database directly.
2. **Public Web Check-in Form** — A simple, no-login web page that participants reach by scanning a QR code. Participants self-report Name, Age, and Skill Level. Submits directly to the backend API.
3. **Flutter Mobile App (Organizer Tool)** — Used only by fellowship organizers/coaches. Lets them create weekly sessions, choose a team format (5v5, 4v4, 3v3), watch attendees check in live, generate skill-balanced teams, manually add players (including late arrivals) without disrupting existing rosters, and review historical session data.

Participants do **not** need to install anything or create an account. Organizers use the Flutter app.

---

## 2. TECH STACK

| Layer | Technology |
|---|---|
| Backend framework | Python 3.11+, FastAPI |
| Database | PostgreSQL |
| ORM | SQLAlchemy (or SQLModel) |
| DB migrations | Alembic |
| Mobile app | Flutter (Dart), organizer-facing only |
| Web check-in form | Plain HTML/CSS/JS (or lightweight framework) — no build step required, kept simple |
| API communication | REST/JSON over HTTPS |
| Auth | None required for MVP (public form has no login; Flutter app can be open for now — see Section 9 for future considerations) |

### Naming conventions
- Backend project folder: `ysf-basketball-api`
- Flutter app package name: `ysf_basketball_app` (underscores required — Dart package naming rules)
- Database name: `ysf_basketball_db`
- Web check-in form folder: `ysf-basketball-checkin`

---

## 3. SEPARATION OF RESPONSIBILITIES

This project should be treated as **three independently buildable and testable modules**, connected only through the REST API contract defined in Section 5. This allows an agent (or team) to build/test each piece in isolation.

### Module A — Backend (`ysf-basketball-api`)
**Owns:**
- PostgreSQL schema and migrations
- All business logic: team balancing/snake-draft algorithm, "add player to best-fit team" logic, session state management
- All validation (age must be a reasonable number, skill_level must be one of the 3 allowed values, team_format must be one of 5v5/4v4/3v3)
- Exposing REST endpoints exactly as defined in Section 5
- CORS configuration so both the web form and Flutter app can call it

**Does NOT own:** any UI, any rendering, any Flutter code.

### Module B — Web Check-in Form (`ysf-basketball-checkin`)
**Owns:**
- Single public page with a form: Name, Age, Skill Level (dropdown/radio: beginner / intermediate / pro)
- Client-side validation (required fields, age is a number)
- Visual theme matching the "Elevate YSF" brand (see Section 8 — Design System)
- POSTs to `POST /sessions/{session_id}/checkin` on the backend
- Shows a simple confirmation message after successful submit
- The session_id is embedded in the QR code URL itself, e.g. `https://yourdomain.com/checkin?session=12`

**Does NOT own:** any database logic, any team logic, any organizer features.

### Module C — Flutter App (`ysf_basketball_app`)
**Owns:**
- All organizer-facing screens (see Section 7)
- Calling backend endpoints for everything (session CRUD, attendee list, team generation, manual add, stats/history)
- Local UI state only — no local database, no offline queueing (per requirements, app is online-only)
- Visual theme matching Section 8

**Does NOT own:** any business logic duplication. If the Flutter app needs to know how teams are balanced, it should call the backend endpoint — it should never re-implement the balancing algorithm client-side.

### Golden rule for the agent
If a piece of logic decides *what the data should be* (team assignment, validation, skill balancing) → it belongs in the **Backend**.
If a piece of logic decides *how something looks or is displayed* → it belongs in the **Web Form** or **Flutter App**.

---

## 4. DATABASE SCHEMA (PostgreSQL)

```sql
CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    session_date DATE NOT NULL,
    week_label VARCHAR(50),
    team_format VARCHAR(10) NOT NULL CHECK (team_format IN ('5v5','4v4','3v3')),
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Attendance is per-session only. No cross-week identity matching is required
-- (per project decision: attendance is tracked for NUMBERS, not strict individual history).
CREATE TABLE attendees (
    id SERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    age INT NOT NULL CHECK (age > 0 AND age < 100),
    skill_level VARCHAR(20) NOT NULL CHECK (skill_level IN ('beginner','intermediate','pro')),
    source VARCHAR(10) NOT NULL DEFAULT 'qr' CHECK (source IN ('qr','manual')),
    checked_in_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE teams (
    id SERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    team_name VARCHAR(50) NOT NULL
);

CREATE TABLE team_members (
    id SERIAL PRIMARY KEY,
    team_id INT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    attendee_id INT NOT NULL REFERENCES attendees(id) ON DELETE CASCADE,
    added_via VARCHAR(20) NOT NULL DEFAULT 'generate' CHECK (added_via IN ('generate','manual-add')),
    added_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(attendee_id) -- an attendee can only be on one team per session
);
```

**Notes for the agent:**
- Use Alembic migrations from the start, even for the first schema — future changes are inevitable.
- `attendees.source` distinguishes QR self-check-in vs organizer manual entry — useful for stats later.
- `team_members.added_via` distinguishes players placed during a full "Generate Teams" pass vs a later "Add Player" action — required for the "don't disrupt existing rosters" requirement.

---

## 5. API CONTRACT (FastAPI)

Base path: `/api/v1`

| Method | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/sessions` | Create a new session. Body: `{session_date, week_label, team_format}` | Organizer |
| GET | `/sessions` | List all sessions (history), most recent first | Organizer |
| GET | `/sessions/{id}` | Get single session detail | Organizer |
| PATCH | `/sessions/{id}` | Update team_format or status | Organizer |
| POST | `/sessions/{id}/checkin` | **Public.** Body: `{name, age, skill_level}`. Creates attendee with `source='qr'` | None (public) |
| POST | `/sessions/{id}/attendees` | Organizer manual add. Body: `{name, age, skill_level}`, `source='manual'` | Organizer |
| GET | `/sessions/{id}/attendees` | List all attendees for a session (live list) | Organizer |
| POST | `/sessions/{id}/teams/generate` | Full randomize/reshuffle. See Section 6 for algorithm. Overwrites existing team_members for this session (requires confirm on frontend). | Organizer |
| POST | `/sessions/{id}/teams/add-player` | Body: `{attendee_id}`. Assigns ONE attendee to whichever existing team is currently most in need of their skill tier, without touching other assignments. | Organizer |
| GET | `/sessions/{id}/teams` | Returns all teams + their current member list for the session | Organizer |
| GET | `/sessions/{id}/stats` | Returns total attendance count and skill-level breakdown (count of beginner/intermediate/pro) | Organizer |

**Response format example — `GET /sessions/{id}/teams`:**
```json
{
  "session_id": 12,
  "team_format": "5v5",
  "teams": [
    {
      "team_id": 1,
      "team_name": "Team A",
      "members": [
        {"attendee_id": 5, "name": "Miguel", "age": 14, "skill_level": "pro"},
        {"attendee_id": 9, "name": "Anna", "age": 13, "skill_level": "beginner"}
      ]
    }
  ]
}
```

**Validation rules (enforced server-side, not just client-side):**
- `skill_level` must be exactly one of: `beginner`, `intermediate`, `pro`
- `team_format` must be exactly one of: `5v5`, `4v4`, `3v3`
- `age` must be a positive integer, reasonable range (e.g. 4–19 for youth fellowship — adjust as needed)
- `/checkin` and `/attendees` reject empty `name`

**CORS:** Backend must allow requests from both the web check-in form's domain and the Flutter app (mobile apps typically don't need CORS, but during local web-based Flutter testing it matters — allow all origins in dev, restrict in production).

---

## 6. TEAM BALANCING ALGORITHM (Core Business Logic)

This lives entirely in the **Backend**.

### 6.1 `POST /sessions/{id}/teams/generate`
1. Fetch all attendees for the session.
2. Determine team size from `team_format` (5v5 → 5 per team, 4v4 → 4, 3v3 → 3).
3. Calculate number of teams needed: `num_teams = ceil(total_attendees / team_size)`.
4. Group attendees into three lists by skill_level: `pro`, `intermediate`, `beginner`.
5. Shuffle each list randomly (use a proper randomization function, e.g. Python's `random.shuffle`).
6. **Snake draft distribution:** Distribute players across `num_teams` in snake order (Team 1→2→3→...→N, then N→...→2→1, repeating) starting with the `pro` list, then `intermediate`, then `beginner`. This ensures each team gets a fair mix of skill levels rather than clustering all pros on one team.
7. Any remainder (uneven division) is spread one-per-team across the last teams in the rotation rather than dumping all leftovers onto a single team — the snake draft pattern naturally achieves this if followed correctly through all three skill groups.
8. Delete any existing `team_members` rows for this session (and existing `teams` rows), then create fresh `teams` and `team_members` rows reflecting the new distribution, all marked `added_via='generate'`.
9. Return the new team list (same shape as `GET /sessions/{id}/teams`).

**Important:** This action is destructive to the current roster and should require a confirmation step in the Flutter UI before calling it, since regenerating undoes any manual adjustments made via `add-player`.

### 6.2 `POST /sessions/{id}/teams/add-player`
Used for late arrivals — must NOT affect any existing team assignments.

1. Fetch the target attendee (must not already be assigned to a team in this session — return an error if they are).
2. Fetch all current teams for the session and their current member skill-level composition.
3. Calculate, for each team, the count of members per skill level.
4. Assign the new attendee to the team that currently has the **fewest members of that attendee's skill level** (tie-break: the team with the fewest total members overall, to also keep team sizes even).
5. Insert a new `team_members` row with `added_via='manual-add'`.
6. Return the updated team list.

This logic guarantees late arrivals are slotted in a way that keeps the skill balance reasonable, without reshuffling anyone already placed.

---

## 7. FLUTTER APP — SCREENS & STRUCTURE

```
lib/
 ├── main.dart
 ├── screens/
 │    ├── session_list_screen.dart      // History: list of past + current sessions
 │    ├── new_session_screen.dart       // Create session: date picker + team_format picker (5v5/4v4/3v3)
 │    ├── session_dashboard_screen.dart // Live attendee count, "Generate Teams" button, session status
 │    ├── manual_add_attendee_screen.dart // Form: Name, Age, Skill Level (organizer backup entry)
 │    ├── team_rosters_screen.dart      // Shows generated teams as cards; "Add Late Player" action
 │    └── session_stats_screen.dart     // Attendance totals + skill level breakdown chart/list
 ├── models/
 │    ├── session.dart
 │    ├── attendee.dart
 │    └── team.dart
 ├── services/
 │    └── api_service.dart              // All HTTP calls to the backend (use `http` or `dio` package)
 └── widgets/
      ├── team_card.dart
      ├── attendee_list_tile.dart
      └── skill_level_badge.dart        // Color-coded badge (e.g. red accent for pro)
```

**Navigation flow:**
`Session List` → (tap "+ New Session") → `New Session` → (created) → `Session Dashboard` → (tap "Generate Teams") → `Team Rosters` → (tap "Add Late Player") → back to `Team Rosters` (updated) → (tap "Stats") → `Session Stats`

**State management:** For an MVP, `Provider` or `Riverpod` is sufficient — avoid over-engineering with something like BLoC unless the agent/owner is already familiar with it.

**HTTP package:** Use `http` (simplest) or `dio` (more features, interceptors) — either is fine; `http` is recommended for a first mobile project since it has a smaller learning curve.

---

## 8. DESIGN SYSTEM (applies to both Web Form and Flutter App)

Based on the "Elevate YSF" logo (black hand-drawn marker lettering, one red accent stroke):

- **Background:** White (#FFFFFF)
- **Primary text/ink color:** Near-black (#1A1A1A)
- **Accent color:** Red (#D9291C or similar — sample from the logo if possible)
- **Typography:** Bold, rounded, energetic display font for headers (e.g. Google Fonts: Baloo 2, Bungee, or Poppins Bold). Clean sans-serif (e.g. Inter, Roboto) for form fields and body text.
- **Buttons:** Primary actions (Generate Teams, Submit) in red with white text; secondary actions outlined in black.
- **Tone:** High-energy, streetball/youth-fellowship feel — not corporate or sterile. Rounded corners, generous spacing, bold labels.

---

## 9. BUILD ORDER (Recommended Sequence for the Agent)

1. **Backend setup:** PostgreSQL database + FastAPI project skeleton + Alembic migrations for the schema in Section 4.
2. **Backend core endpoints:** Session CRUD, `/checkin`, `/attendees` (manual add), `GET /attendees` — test with a REST client (e.g. curl or Postman) before building any UI.
3. **Backend team logic:** Implement and unit-test the snake-draft algorithm (Section 6.1) and add-player logic (Section 6.2) in isolation before wiring to endpoints.
4. **Web check-in form:** Build the static form, style it per Section 8, connect it to `/checkin`. Test the full QR-scan-to-submit flow.
5. **Flutter app — read-only screens first:** Session List, New Session, Session Dashboard showing live attendee list (connect to real backend).
6. **Flutter app — team screens:** Team Rosters screen, Generate Teams button, Add Late Player flow.
7. **Flutter app — stats/history:** Session Stats screen.
8. **Polish pass:** Apply full design system consistently, add loading states, error handling (e.g. what happens if the backend is unreachable), and confirmation dialogs (especially for "Generate Teams" since it's destructive).

---

## 10. FUTURE CONSIDERATIONS (not required for MVP, but worth noting)
- Organizer login/auth if multiple fellowship chapters will use the same backend and need data separation.
- Cross-week participant identity (if attendance-per-individual tracking ever becomes a real requirement instead of just headcounts).
- Push notifications or SMS reminders for sessions.
- Exporting session data (CSV) for offline record-keeping.

---

## 11. HOW TO RUN THIS PROJECT LOCALLY (Beginner-Friendly Instructions)

This section assumes no prior mobile development experience.

### 11.1 Install the required tools (one-time setup)

1. **Install PostgreSQL**
   - Download from https://www.postgresql.org/download/ and install for your OS.
   - During setup, remember the password you set for the default `postgres` user.
   - After install, create the database:
     ```
     psql -U postgres
     CREATE DATABASE ysf_basketball_db;
     \q
     ```

2. **Install Python 3.11+**
   - Download from https://www.python.org/downloads/
   - Verify install: open a terminal and run `python3 --version`

3. **Install Flutter SDK**
   - Follow the official guide for your OS: https://docs.flutter.dev/get-started/install
   - This also installs Dart (Flutter includes Dart automatically).
   - Verify install: `flutter doctor` — this command checks your setup and tells you what's missing (e.g. Android Studio, Xcode for iOS). Follow its instructions to fix any red ✗ items.

4. **Install an editor**
   - VS Code (recommended for beginners) with the "Flutter" and "Dart" extensions, and the "Python" extension.

5. **Install a mobile emulator or use a physical phone**
   - Easiest option: install the **Android Studio** emulator (comes with Android Studio) — lets you run the app on a virtual phone on your computer.
   - Alternative: install the **Expo Go**-style approach isn't applicable here since this is native Flutter — instead, you can plug in your own Android phone via USB with "Developer Mode" + "USB Debugging" enabled, and Flutter will detect it as a run target.

### 11.2 Running the Backend

```bash
# from inside the ysf-basketball-api folder
python3 -m venv venv
source venv/bin/activate        # on Windows: venv\Scripts\activate
pip install -r requirements.txt

# set your database connection string as an environment variable
export DATABASE_URL="postgresql://postgres:yourpassword@localhost:5432/ysf_basketball_db"

# run migrations
alembic upgrade head

# start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
- Once running, open `http://localhost:8000/docs` in a browser — FastAPI auto-generates an interactive API test page. This is the easiest way to test endpoints before the Flutter app exists.

### 11.3 Running the Web Check-in Form
- If it's a plain HTML/CSS/JS page, you can open it directly in a browser, or serve it locally:
  ```bash
  cd ysf-basketball-checkin
  python3 -m http.server 5500
  ```
  Then visit `http://localhost:5500` in a browser.
- Make sure the form's API call points to `http://localhost:8000/api/v1/...` while testing locally.

### 11.4 Running the Flutter App

```bash
# from inside the ysf_basketball_app folder
flutter pub get          # installs dependencies

# list available devices (emulator or connected phone)
flutter devices

# run the app on the first available device
flutter run
```
- If using an Android emulator: open Android Studio → "Device Manager" → start a virtual device first, then run `flutter run`.
- If using a real phone: enable Developer Mode + USB Debugging on the phone, connect via USB, then run `flutter run` — select your phone from the list if prompted.
- The app will hot-reload automatically as code changes if you leave `flutter run` active — press `r` in the terminal to manually hot-reload, or `R` for a full restart.
- Make sure `api_service.dart` points to your backend's address. **Note:** if testing on a physical device or emulator, `localhost` may not refer to your computer — Android emulators use `10.0.2.2` to reach your computer's `localhost`; physical devices need your computer's actual local network IP address (e.g. `192.168.1.x`), with both devices on the same Wi-Fi network.

### 11.5 Generating the QR Code
- The QR code simply needs to encode the URL to the web check-in form, including the session ID, e.g.:
  `https://yourdomain.com/checkin?session=12`
- For local testing, any free QR generator (e.g. `qrcode` Python package, or an online generator) can turn that URL into a scannable image. This can be automated later (e.g. the Flutter app generates and displays the QR code for the current session).

### 11.6 Suggested order to test everything end-to-end
1. Start PostgreSQL.
2. Start the backend (`uvicorn`), confirm `/docs` loads.
3. Create a session via `/docs` manually, note its `id`.
4. Open the web check-in form, submit a test entry, confirm it appears via `GET /sessions/{id}/attendees` in `/docs`.
5. Run the Flutter app, confirm the Session Dashboard shows that same attendee.
6. Tap "Generate Teams," confirm rosters appear.
7. Add one more attendee manually, use "Add Late Player," confirm existing rosters are unchanged.

---

## 12. DATABASE HOSTING — SUPABASE (Always-On Postgres)

Running Postgres on a local machine only works while that machine is on and only for devices on the same network. Since participants will scan QR codes from their own phones (different networks, different times), the database needs to be hosted somewhere always-on and publicly reachable. This project uses **Supabase** for that.

### 12.1 What Supabase is
Supabase is a hosted Postgres provider — it **is** just Postgres underneath, with a web dashboard on top. No schema, query, or ORM changes are needed compared to local Postgres; only the connection string changes.

### 12.2 Creating the Supabase project
1. Go to https://supabase.com and sign up (free tier is sufficient for this project's scale).
2. Click **"New Project"**.
3. Fill in:
   - **Name:** `ysf-basketball`
   - **Database Password:** set a strong password and store it securely (e.g. in a password manager) — it is required for the connection string and is not easily recoverable later.
   - **Region:** choose the region closest to where the fellowship takes place, to minimize latency.
4. Click **Create new project** and wait for provisioning (~1–2 minutes).

### 12.3 Retrieving the connection string
1. In the project dashboard: **Project Settings** (gear icon) → **Database**.
2. Under **Connection string**, use the **Connection pooling** URI (not the direct connection) — FastAPI opens many short-lived connections, and the pooler is built for that pattern. It typically runs on port `6543`:
   ```
   postgresql://postgres.xxxxxxxxxxxx:[YOUR-PASSWORD]@aws-0-region.pooler.supabase.com:6543/postgres
   ```
3. Replace `[YOUR-PASSWORD]` with the database password set in Step 12.2.

### 12.4 Using it in the backend
This connection string replaces the local `DATABASE_URL` used during development. No other code changes:
```bash
export DATABASE_URL="postgresql://postgres.xxxxxxxxxxxx:[YOUR-PASSWORD]@aws-0-region.pooler.supabase.com:6543/postgres"
alembic upgrade head
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Alembic migrations run against Supabase exactly as they would against a local database — this creates the `sessions`, `attendees`, `teams`, and `team_members` tables (Section 4) inside the hosted database.

### 12.5 Recommended workflow: local dev DB vs. production DB
To avoid accidentally corrupting real fellowship data while testing:
- Keep a **local Postgres database** for day-to-day development and experimentation (as described in Section 11.1–11.2).
- Use the **Supabase database** only for the deployed/production backend that the real QR check-in form and organizer app point to.
- Never point local development work directly at the Supabase production database unless intentionally testing against real data.

### 12.6 Deploying the backend itself (so it's reachable, not just the database)
Supabase hosts the **database only** — it does not run your FastAPI code. For phones to reach the check-in form and for the Flutter app to reach the API from anywhere, the FastAPI backend also needs to run somewhere always-on. Recommended options, both of which connect easily to a Supabase `DATABASE_URL`:

- **Railway** (https://railway.app) — connect your backend's GitHub repo, set the `DATABASE_URL` environment variable to the Supabase pooler string, deploy. Free tier available.
- **Render** (https://render.com) — similar workflow: deploy a "Web Service" from the repo, set the same environment variable.

Once deployed, the backend gets a public URL (e.g. `https://ysf-basketball-api.up.railway.app`). This becomes:
- The base URL the **web check-in form** submits to.
- The base URL the **Flutter app's `api_service.dart`** points to (replacing `localhost` or the local network IP used during development).

### 12.7 Environment variable checklist
| Where | Variable | Value |
|---|---|---|
| Local dev | `DATABASE_URL` | Local Postgres connection string |
| Production (Railway/Render) | `DATABASE_URL` | Supabase pooler connection string |
| Web check-in form | API base URL (in JS config) | Deployed backend's public URL |
| Flutter app | API base URL (in `api_service.dart`) | Deployed backend's public URL |

---

*End of specification.*
