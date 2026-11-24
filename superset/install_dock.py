#!/usr/bin/env python3
"""Put the "Ask the agent" dock on a Superset dashboard: tile markup into a Markdown component,
dock.css into the dashboard's own `css` field. Idempotent: a re-run replaces the previous dock tile
and the previous marker block, and leaves the dashboard's own CSS untouched.
"""

import argparse
import http.cookiejar
import json
import pathlib
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
ROW, TILE = "ROW-dock", "MARKDOWN-dock"
CSS_START, CSS_END = "/* ai-dock:start */", "/* ai-dock:end */"


def merge_css(existing: str, dock_css: str) -> str:
    """Put the dock between markers in a dashboard's CSS, replacing a previous block in place."""
    block = f"{CSS_START}\n{dock_css.strip()}\n{CSS_END}"
    start = existing.find(CSS_START)
    end = existing.find(CSS_END, start) if start != -1 else -1
    if end != -1:
        return existing[:start] + block + existing[end + len(CSS_END):]
    return f"{existing.rstrip()}\n\n{block}\n" if existing.strip() else f"{block}\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--superset", default="http://localhost:8088")
    ap.add_argument("--user", default="admin")
    ap.add_argument("--password", default="admin")
    ap.add_argument("--dashboard", type=int, required=True, help="Superset dashboard id to install on")
    ap.add_argument("--agent", default="http://localhost:5005", help="origin serving /embed/chat")
    a = ap.parse_args()

    api = a.superset.rstrip("/") + "/api/v1"
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    headers = {"Content-Type": "application/json"}

    def call(method, path, body=None):
        req = urllib.request.Request(
            api + path, method=method, data=json.dumps(body).encode() if body else None, headers=headers
        )
        return json.load(opener.open(req))

    login = {"username": a.user, "password": a.password, "provider": "db"}
    headers["Authorization"] = "Bearer " + call("POST", "/security/login", login)["access_token"]
    # A bearer token alone is not enough for writes: Superset also wants the session cookie's CSRF.
    headers["X-CSRFToken"] = call("GET", "/security/csrf_token/")["result"]
    headers["Referer"] = a.superset

    src = f"{a.agent.rstrip('/')}/embed/chat?dashboard_id={a.dashboard}"
    code = (HERE / "dock_tile.md").read_text().replace("{{SRC}}", src).strip()

    dash = call("GET", f"/dashboard/{a.dashboard}")["result"]
    pos = json.loads(dash["position_json"] or "{}")
    for key in (ROW, TILE):
        pos.pop(key, None)
    for node in pos.values():
        if isinstance(node, dict) and ROW in node.get("children", []):
            node["children"].remove(ROW)

    # The visible layout hangs off ROOT_ID, and may be TABS -> TAB rather than a GRID; a row put
    # under an unreferenced GRID is saved but never rendered.
    parent = pos["ROOT_ID"]["children"][0]
    while pos[parent]["type"] == "TABS":
        parent = pos[parent]["children"][0]
    chain = pos[parent].get("parents", ["ROOT_ID"]) + [parent]
    pos[ROW] = {"type": "ROW", "id": ROW, "children": [TILE], "parents": chain,
                "meta": {"background": "BACKGROUND_TRANSPARENT"}}
    pos[TILE] = {"type": "MARKDOWN", "id": TILE, "children": [], "parents": chain + [ROW],
                 "meta": {"code": code, "width": 1, "height": 4}}
    pos[parent]["children"].insert(0, ROW)

    call("PUT", f"/dashboard/{a.dashboard}",
         {"position_json": json.dumps(pos),
          "css": merge_css(dash.get("css") or "", (HERE / "dock.css").read_text())})
    print(f"dock installed on dashboard {a.dashboard}: {a.superset}/superset/dashboard/{a.dashboard}/ -> {src}")


if __name__ == "__main__":
    main()
