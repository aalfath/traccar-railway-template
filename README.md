# Traccar on Railway

This repo packages the official [Traccar](https://www.traccar.org) server image for one-click deployment on [Railway](https://railway.com).

Traccar is an open-source GPS tracking platform. It receives positions from more than 200 GPS tracker protocols and from the Traccar Client phone app, stores them in a database, and shows live positions, history, geofences, alerts and reports in a web app.

## What it deploys

| Service | Builds from | Version |
|---|---|---|
| `Traccar` | this repo (`Dockerfile`) | `traccar/traccar:6.17.0-alpine` pinned by digest `sha256:b32d9346adf46df7c33c58577e17ad60f6feadd1f3cd87c876041f6c79317ef1` |
| `Postgres` | Railway's PostgreSQL | Railway's managed Postgres image, with its own volume |

- The `Traccar` service has a public Railway domain (web app and API on port `8082`) and a volume at `/opt/traccar/data` (media files such as device photos, and the bootstrap marker).
- All tracking data lives in Postgres, as Traccar recommends for production instead of its embedded H2 database.
- The health check is `/api/health`, which also checks the database connection.

The wrapper is one start script, `railway-start.sh`. It writes `conf/traccar.xml` from the environment (Postgres from `DATABASE_URL`, `web.port` from `PORT`, `web.url` from the Railway domain, logs to the console). On the first start against an empty database it runs Traccar on `127.0.0.1` only, creates the administrator from `TRACCAR_ADMIN_EMAIL` and `TRACCAR_ADMIN_PASSWORD`, and only then starts Traccar on the public port. Upstream Traccar makes the first person who signs up the administrator; this closes that window. Self-registration stays off.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Postgres connection, over Railway's private network |
| `PORT` | `8082` | Port of the web app and API; the Railway domain points at it |
| `TRACCAR_ADMIN_EMAIL` | `admin` | Login of the administrator created on the first start |
| `TRACCAR_ADMIN_PASSWORD` | generated (`${{secret(24)}}`) | Password of that administrator. Read it in the service's Variables tab |

Change the administrator's email and password in Traccar (**Settings → Account**) after you sign in. Changing the two variables later has no effect: they're only used on the first start.

Any other [Traccar setting](https://www.traccar.org/configuration-file/) can be added as a variable on the `Traccar` service: the key in upper case with dots as underscores. For example `MAIL_SMTP_HOST`, `MAIL_SMTP_PORT`, `MAIL_SMTP_USERNAME`, `MAIL_SMTP_PASSWORD` and `MAIL_SMTP_FROM` for email notifications, or `GEOCODER_ENABLE=true` for addresses. `JAVA_OPTS` adds JVM flags (for example `-Xmx512m`).

## Connecting devices

- **Traccar Client (Android, iOS):** set the server URL to `https://YOUR-DOMAIN` (Traccar forwards OsmAnd posts on the web port to its OsmAnd protocol), add a device in the web app with the identifier the app shows, and start the service.
- **Hardware trackers:** most trackers speak a TCP protocol on its own port (for example `5023` for GT06, `5027` for Teltonika; see the [device list](https://www.traccar.org/devices/)). Add a **TCP Proxy** for that port in the `Traccar` service's Settings → Networking, then point the tracker at the proxy's host and port. Railway has no UDP proxy, so set UDP-only devices to TCP.

## Updates

Railway notifies everyone who deployed this template when a change is merged to `main`. Each update bumps the pinned image in the `Dockerfile` and is described in [CHANGELOG.md](CHANGELOG.md), breaking changes first. Traccar migrates its database schema itself on start; back up Postgres before applying a major version.
