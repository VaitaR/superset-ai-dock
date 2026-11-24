FROM apache/superset:6.1.0
USER root
# The stock image ships no Postgres driver; the metadata DB and the example data both live in Postgres.
RUN uv pip install --python /app/.venv/bin/python psycopg2-binary
USER superset
