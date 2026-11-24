# superset-ai-dock

An open-source analytics agent ([nao](https://github.com/getnao/nao)) embedded as an "Ask the agent"
chat dock inside an Apache Superset dashboard. Superset 6.1.0 runs in Docker with its example data;
nao runs from a pinned upstream commit plus a four-patch series.

## Run

Needs Docker, bun, uv, node 22 and python 3.

```sh
OPENAI_API_KEY=... ./up.sh     # the key is only needed for answers; the dock renders without it
```

Then open the printed dashboard URL (Superset login `admin` / `admin`), and sign in once to the
agent at `http://localhost:5005` (`demo@example.com` / `demo-password-123`) in the same browser.
The dock reuses that session. Stop with `docker compose -f superset/docker-compose.yml down` and
`kill $(cat .work/run/*.pid)`. Local demo credentials only; nothing here is meant to face a network.

## How it works

```
superset/   docker compose (Postgres + Superset 6.1.0), superset_config.py, dock tile, dock.css,
            install_dock.py
nao/        NAO_COMMIT (pinned upstream), patches/*.patch, apply.sh
context/    nao project: nao_config.yaml (Postgres connection to the example data), RULES.md,
            dashboards/ + datasets/ generated from the Superset REST API (scripts/gen_context.py)
scripts/    gen_context.py, find_dashboard.py, effort.sh
```

- **Superset side.** A Markdown tile holds `<details><summary>Ask the agent</summary>…<iframe>…`.
  `dock.css`, stored in the dashboard's own `css` field, pins that `<details>` to the bottom-right
  corner. `install_dock.py` writes the tile and the CSS through the REST API. Two settings let the
  frame through: `HTML_SANITIZATION_SCHEMA_EXTENSIONS` allows `<iframe>`, and the CSP `frame-src`
  names the agent's origin.
- **Agent side** (`nao/patches/`). A frontend route `/embed/chat` that reads `q`, `dashboard_id`,
  `chart_id`, `filters`, `time_range` and `autosend` from the URL; a `frame-ancestors` response header
  on `/embed/*` limited to `SUPERSET_EMBED_ORIGIN`; and a `supersetContext` field on the chat message
  that the backend renders as a short block for the model.
- **Context.** The iframe `src` carries the real Superset dashboard id. The model is told to search
  the project context for that id, and `context/dashboards/<id>-*.md` is keyed by it, so no mapping
  table exists. Regenerate with `python3 scripts/gen_context.py`.

## Constraints that shaped the dock (Superset 6.1.0)

- The Markdown sanitizer strips `<script>`, `<label>` and the `class`, `id` and `open` attributes,
  so open/close/enlarge use `<details>`/`<summary>` and the CSS addresses the dock by structure
  (`.dashboard-markdown details:has(> iframe)`).
- The CSS lives in the dashboard's `css` field, not a `<style>` in the tile, so the sanitizer needs
  no `style` allowance.
- `position: fixed` inside a tile resolves against `.dragdroppable-column`, which carries an identity
  `transform`. `dock.css` neutralises it outside edit mode, so edit-mode drag keeps working.
- Any `transform` on an ancestor becomes the dock's containing block. The carrier tile is a
  chart-holder, so a dashboard's own `:hover { transform: translateY(-4px) }` rule would move the dock
  away from the pointer and make it flicker; `dock.css` pins `transform: none` there. After installing
  on a new dashboard, hover and click the dock once; a custom CSS rule is the usual suspect.
- The stock CSP has no `frame-src`, so `default-src 'self'` blocks the frame. Extend the stock
  `TALISMAN_CONFIG` (deepcopy it) instead of replacing it.
- Voice input needs `allow="microphone"` on the iframe: a cross-origin frame gets no microphone
  without that delegation. A previously denied choice persists per origin.
- A Markdown tile does no templating, so the iframe `src` is fixed when the tile is authored.
- Check both colour schemes; `dock.css` has a `prefers-color-scheme: dark` block.

## What the agent cannot get

- The user's current filter selection. The tile is static, the frame cannot read the parent URL, and
  the URL only holds a `native_filters_key` hash. The agent knows which filters a dashboard offers
  (from the generated context), not which values are applied.
- The `filters` and `time_range` URL parameters exist for a caller that does know them (a link, a
  custom tile); this demo's static tile sends only `dashboard_id`.

## Ported by hand

The patches were written against upstream's current structure from a private fork's implementation;
they are not cherry-picks. What the fork had beyond this was dropped: a home-route deep link, the
MCP tool's context argument, usage attribution for the embed entry point, a curated context pack
and its filter sync. Upstream already has the shared-chart embed layout the new route sits under.

`nao/apply.sh` clones the pinned commit into `.work/nao` and applies the series with `git am`.
`apps/frontend/src/routeTree.gen.ts` is not in the patches: the router plugin regenerates it when
the frontend is built.

The numbers behind the article are in [EFFORT.md](EFFORT.md).

## Screenshots and video

With the stack up, `PW_DIR=<dir with playwright-core> node scripts/capture.mjs` writes the collapsed
and expanded dock, one answered question and the raw recording to `media/` and `.work/video/`
(both gitignored; the question needs `OPENAI_API_KEY` in the environment of `up.sh`).
