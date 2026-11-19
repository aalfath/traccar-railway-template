# Changelog

## 6.17.0 (2026-11-19)

- First release of the template: Traccar 6.17.0 (`traccar/traccar:6.17.0-alpine@sha256:b32d9346adf46df7c33c58577e17ad60f6feadd1f3cd87c876041f6c79317ef1`) with Railway Postgres.
- The start script writes `conf/traccar.xml` from `DATABASE_URL` and `PORT`, logs to the console, and creates the first administrator from `TRACCAR_ADMIN_EMAIL` / `TRACCAR_ADMIN_PASSWORD` before the web port opens.
