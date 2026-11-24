#!/usr/bin/env python3
"""Print the id of the Superset dashboard with the given title (exit 1 if there is none)."""

import argparse
import http.cookiejar
import json
import sys
import urllib.parse
import urllib.request


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("title")
    ap.add_argument("--superset", default="http://localhost:8088")
    ap.add_argument("--user", default="admin")
    ap.add_argument("--password", default="admin")
    a = ap.parse_args()

    api = a.superset.rstrip("/") + "/api/v1"
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    headers = {"Content-Type": "application/json"}
    login = urllib.request.Request(
        api + "/security/login",
        data=json.dumps({"username": a.user, "password": a.password, "provider": "db"}).encode(),
        headers=headers,
    )
    headers["Authorization"] = "Bearer " + json.load(opener.open(login))["access_token"]
    q = urllib.parse.quote(json.dumps({"page_size": 100}))
    result = json.load(opener.open(urllib.request.Request(f"{api}/dashboard/?q={q}", headers=headers)))["result"]
    for d in result:
        if d["dashboard_title"] == a.title:
            print(d["id"])
            return
    sys.exit(f"no dashboard titled {a.title!r}; found: {[d['dashboard_title'] for d in result]}")


if __name__ == "__main__":
    main()
