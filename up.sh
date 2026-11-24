#!/usr/bin/env bash
# One command: Superset (Docker) + patched nao + the dock installed on a dashboard.
#   OPENAI_API_KEY=... ./up.sh        # the key is only needed to get answers from the agent
# Environment: DOCK_DASHBOARD (dashboard id, default: the "Sales Dashboard" example),
# SUPERSET_URL, AGENT_URL, NAO_DIR.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUPERSET_URL="${SUPERSET_URL:-http://localhost:8088}"
AGENT_URL="${AGENT_URL:-http://localhost:5005}"
export NAO_DIR="${NAO_DIR:-$ROOT/.work/nao}"
RUN="$ROOT/.work/run"
mkdir -p "$RUN"

wait_for() { # url, seconds
  local end=$((SECONDS + $2))
  until curl -fs -o /dev/null "$1"; do
    [ $SECONDS -lt $end ] || { echo "timeout waiting for $1" >&2; exit 1; }
    sleep 3
  done
}

echo "== Superset"
docker compose -f "$ROOT/superset/docker-compose.yml" up -d --build
wait_for "$SUPERSET_URL/health" 1200

echo "== Context from the Superset REST API"
python3 "$ROOT/scripts/gen_context.py" --superset "$SUPERSET_URL"

DASHBOARD="${DOCK_DASHBOARD:-$(python3 "$ROOT/scripts/find_dashboard.py" --superset "$SUPERSET_URL" "Sales Dashboard")}"

echo "== nao: patched checkout, dependencies, frontend build"
if [ ! -d "$NAO_DIR/.git" ] || [ "$(git -C "$NAO_DIR" rev-list --count "$(cat "$ROOT/nao/NAO_COMMIT")"..HEAD)" != "$(ls "$ROOT"/nao/patches/*.patch | wc -l | tr -d ' ')" ]; then
  "$ROOT/nao/apply.sh"
fi
(cd "$NAO_DIR" && bun install >"$RUN/bun-install.log" 2>&1)
(cd "$NAO_DIR/apps/frontend" && bun run vite build >"$RUN/frontend-build.log" 2>&1)
(cd "$NAO_DIR/cli" && uv sync --extra postgres >"$RUN/uv-sync.log" 2>&1)

echo "== nao: services"
for name in backend fastapi; do
  [ -f "$RUN/$name.pid" ] && kill "$(cat "$RUN/$name.pid")" 2>/dev/null || true
done
export EXAMPLES_DB_PASSWORD=superset
export NAO_DEFAULT_PROJECT_PATH="$ROOT/context"
export DB_URI="sqlite:$ROOT/.work/nao-data.sqlite"
export BETTER_AUTH_URL="$AGENT_URL/"
export BETTER_AUTH_SECRET="local-demo-only-not-a-secret-0123456789abcdef"
export SUPERSET_EMBED_ORIGIN="$SUPERSET_URL"
(cd "$NAO_DIR/apps/backend" && bun run db:migrate >"$RUN/migrate.log" 2>&1)
(cd "$NAO_DIR/cli" && nohup uv run ../apps/backend/fastapi/main.py >"$RUN/fastapi.log" 2>&1 & echo $! >"$RUN/fastapi.pid")
(cd "$NAO_DIR/apps/backend" && PATH="$NAO_DIR/cli/.venv/bin:$PATH" nohup bun src/index.ts >"$RUN/backend.log" 2>&1 & echo $! >"$RUN/backend.pid")
wait_for "$AGENT_URL/api/health" 180

# The first sign-up on a fresh self-hosted instance becomes the admin of the default project.
curl -sS -o /dev/null -X POST "$AGENT_URL/api/auth/sign-up/email" \
  -H 'Content-Type: application/json' -H "Origin: $AGENT_URL" \
  -d '{"name":"Demo","email":"demo@example.com","password":"demo-password-123"}' || true

echo "== Dock on dashboard $DASHBOARD"
python3 "$ROOT/superset/install_dock.py" --superset "$SUPERSET_URL" --agent "$AGENT_URL" --dashboard "$DASHBOARD"

cat <<EOF

Ready.
  Superset: $SUPERSET_URL/superset/dashboard/$DASHBOARD/   (admin / admin)
  Agent:    $AGENT_URL   (demo@example.com / demo-password-123)
Sign in to the agent once in the same browser; the dock then reuses that session.
EOF
