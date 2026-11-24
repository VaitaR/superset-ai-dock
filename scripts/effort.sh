#!/usr/bin/env bash
# Prints the numbers in EFFORT.md. Needs nao/apply.sh to have produced .work/nao.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAO="${NAO_DIR:-$ROOT/.work/nao}"
BASE="$(cat "$ROOT/nao/NAO_COMMIT")"
numstat() { git -C "$NAO" diff --numstat "$BASE" HEAD -- "$@" | awk '{a+=$1; d+=$2; n++} END {printf "%d files, +%d -%d\n", n, a, d}'; }
EXCL=(':!*.test.ts' ':!apps/frontend/src/routeTree.gen.ts' ':!*/meta/_journal.json')
echo "agent, excluding tests and generated files: $(numstat . "${EXCL[@]}")"
echo "agent, tests only:                          $(numstat '*.test.ts')"
echo "agent, journal metadata (generated):        $(numstat '*/meta/_journal.json')"
echo "patch files: $(ls "$ROOT"/nao/patches/*.patch | wc -l | tr -d ' ')"
echo "superset-side lines (wc -l):"
(cd "$ROOT/superset" && wc -l superset_config.py dock_tile.md dock.css install_dock.py)
echo "superset_config.py code lines (no comments/blank): $(rg -v '^\s*(#|$)' "$ROOT/superset/superset_config.py" | wc -l | tr -d ' ')"
echo "dock tile + dock.css + installer: $(cat "$ROOT"/superset/{dock_tile.md,dock.css,install_dock.py} | wc -l | tr -d ' ')"
echo "superset config settings the integration needs:"
rg -n '^(HTML_SANITIZATION_SCHEMA_EXTENSIONS|TALISMAN_CONFIG\["content_security_policy"\]\["frame-src"\])' "$ROOT/superset/superset_config.py"
echo "other settings in superset_config.py (demo boot, not integration):"
rg -n '^[A-Z_]+ =|^TALISMAN_CONFIG\["force_https"\]' "$ROOT/superset/superset_config.py" | rg -v 'HTML_SANITIZATION_SCHEMA_EXTENSIONS|frame-src'
