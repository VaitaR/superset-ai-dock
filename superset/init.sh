#!/bin/sh
# One-time setup, then the server. Every step is idempotent so a restart is safe.
set -eu

superset db upgrade
superset fab create-admin --username admin --firstname Admin --lastname User \
  --email admin@example.invalid --password admin || true
superset init

# `load_examples` is skipped once the marker exists: it is slow and re-runs overwrite charts.
marker=/app/superset_home/.examples-loaded
if [ "${SUPERSET_LOAD_EXAMPLES:-yes}" = "yes" ] && [ ! -f "$marker" ]; then
  superset load_examples
  touch "$marker"
fi

exec gunicorn --bind 0.0.0.0:8088 --workers 2 --timeout 120 \
  --limit-request-line 0 --limit-request-field_size 0 "superset.app:create_app()"
