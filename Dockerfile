# ═══════════════════════════════════════════════════════════════════════════
#  YSF Basketball — backend container
#
#  Build context is the REPO ROOT (not the api folder) on purpose: the image
#  also carries the public check-in page (ysf-basketball-checkin) so a single
#  always-on deployment serves both the API and the page participants scan.
#
#  Build:  docker build -t ysf-api .
#  Run:    docker run -p 8000:8000 -e DATABASE_URL="postgresql://..." ysf-api
# ═══════════════════════════════════════════════════════════════════════════
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

# Dependencies first so Docker can cache this layer.
COPY ysf-basketball-api/requirements.txt ./ysf-basketball-api/requirements.txt
RUN pip install --no-cache-dir -r ysf-basketball-api/requirements.txt

# Module A (backend) and Module B (public form).
COPY ysf-basketball-api/ ./ysf-basketball-api/
COPY ysf-basketball-checkin/ ./ysf-basketball-checkin/

WORKDIR /app/ysf-basketball-api

EXPOSE 8000

# Apply migrations, then serve. Migrations are idempotent, so a restart or a
# second instance is harmless.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
