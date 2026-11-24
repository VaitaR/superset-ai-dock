# Local demo only: a throwaway container that boots over plain HTTP. Block 1 and block 2 are the
# whole integration; everything else exists so the demo starts on its own.
from copy import deepcopy

import superset.config as base

SECRET_KEY = "local-demo-only-not-a-secret-0123456789abcdef"
SQLALCHEMY_DATABASE_URI = "postgresql+psycopg2://superset:superset@db:5432/superset"
# The agent queries this database too (see context/), so the example datasets live in Postgres.
SQLALCHEMY_EXAMPLES_URI = "postgresql+psycopg2://superset:superset@db:5432/examples"
WTF_CSRF_ENABLED = True
FEATURE_FLAGS = {"DASHBOARD_NATIVE_FILTERS": True}

# Block 1 of 2: keep sanitization on and allow only <iframe>. `class`, `id` and `open` stay
# stripped, which is why dock.css addresses the dock by structure.
HTML_SANITIZATION = True
HTML_SANITIZATION_SCHEMA_EXTENSIONS = {
    "tagNames": ["iframe"],
    "attributes": {
        "iframe": ["src", "width", "height", "frameborder", "style", "allow", "sandbox"],
    },
}

# Block 2 of 2: the stock CSP has no frame-src, so default-src 'self' blocks the frame. Extend the
# stock dict; assigning a fresh one drops the rest of the policy. An existing deployment keeps its
# own CSP dict and adds only the frame-src key, pointing at the agent's origin.
TALISMAN_ENABLED = True
TALISMAN_CONFIG = deepcopy(base.TALISMAN_CONFIG)
TALISMAN_CONFIG["content_security_policy"]["frame-src"] = ["'self'", "http://localhost:5005"]
# Plain HTTP on localhost; without this Talisman redirects every request to https.
TALISMAN_CONFIG["force_https"] = False
