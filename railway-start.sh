#!/bin/sh
# Start Traccar on Railway: write conf/traccar.xml from the environment, create the
# first administrator while the web server listens on localhost only, then start
# Traccar for real. Traccar makes the first user who signs up an administrator, so
# without this step a fresh public instance could be claimed by anyone.
set -eu
cd /opt/traccar

PORT="${PORT:-8082}"
DATA_DIR="${TRACCAR_DATA_DIR:-/opt/traccar/data}"
mkdir -p "$DATA_DIR/media"
JAVA="/opt/traccar/jre/bin/java"
# JAVA_OPTS lets you add JVM flags, e.g. -Xmx512m. Word splitting is intended.
JAVA_ARGS="-XX:+ExitOnOutOfMemoryError ${JAVA_OPTS:-}"

xml() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&apos;/g" -e 's/"/\&quot;/g'; }
json() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# Database: Railway Postgres through DATABASE_URL (postgres[ql]://user:pass@host:port/db).
if [ -n "${DATABASE_URL:-}" ]; then
  rest="${DATABASE_URL#*://}"
  creds="${rest%%@*}"
  hostpart="${rest#*@}"
  DB_USER="${creds%%:*}"
  DB_PASS="${creds#*:}"
  hostport="${hostpart%%/*}"
  dbname="${hostpart#*/}"
  dbname="${dbname%%\?*}"
  case "$hostport" in *:*) ;; *) hostport="$hostport:5432" ;; esac
  DB_DRIVER="org.postgresql.Driver"
  DB_URL="jdbc:postgresql://${hostport}/${dbname}"
  # Traccar reads environment variables as config keys (DATABASE_URL = database.url),
  # so the postgres:// form must not reach it.
  unset DATABASE_URL
else
  echo "[railway] DATABASE_URL is not set: using the embedded H2 database in $DATA_DIR (testing only)."
  DB_DRIVER="org.h2.Driver"
  DB_URL="jdbc:h2:$DATA_DIR/database"
  DB_USER="sa"
  DB_PASS=""
fi

WEB_URL_ENTRY=""
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  WEB_URL_ENTRY="    <entry key='web.url'>https://$(xml "$RAILWAY_PUBLIC_DOMAIN")</entry>"
fi

# Other Traccar settings can be set as environment variables: the key in upper case
# with dots as underscores, e.g. MAIL_SMTP_HOST for mail.smtp.host.
cat > conf/traccar.xml <<XML
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE properties SYSTEM 'http://java.sun.com/dtd/properties.dtd'>
<properties>
    <entry key='config.useEnvironmentVariables'>true</entry>
    <entry key='database.driver'>$(xml "$DB_DRIVER")</entry>
    <entry key='database.url'>$(xml "$DB_URL")</entry>
    <entry key='database.user'>$(xml "$DB_USER")</entry>
    <entry key='database.password'>$(xml "$DB_PASS")</entry>
    <entry key='web.port'>$(xml "$PORT")</entry>
    <entry key='media.path'>$(xml "$DATA_DIR/media")</entry>
    <entry key='logger.console'>true</entry>
$WEB_URL_ENTRY
</properties>
XML

# First-administrator bootstrap. The marker is tied to the database, so pointing the
# service at a new, empty database runs the bootstrap again.
marker="$DATA_DIR/.admin-bootstrap-$(printf '%s|%s' "$DB_URL" "$DB_USER" | sha256sum | cut -c1-16)"
if [ -n "${TRACCAR_ADMIN_PASSWORD:-}" ] && [ ! -f "$marker" ]; then
  echo "[railway] First start for this database: starting Traccar on localhost only to create the administrator."
  # shellcheck disable=SC2086
  WEB_ADDRESS=127.0.0.1 "$JAVA" $JAVA_ARGS -jar tracker-server.jar conf/traccar.xml &
  pid=$!
  i=0
  ok=""
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 900 ]; do
    if server=$(wget -q -T 2 -O - "http://127.0.0.1:${PORT}/api/server" 2>/dev/null); then ok=1; break; fi
    i=$((i + 1)); sleep 1
  done
  if [ -z "$ok" ]; then
    echo "[railway] Traccar did not come up during the bootstrap; stopping."
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    exit 1
  fi
  case "$server" in
    *'"newServer":true'*)
      email="${TRACCAR_ADMIN_EMAIL:-admin}"
      body=$(printf '{"name":"Administrator","email":"%s","password":"%s"}' "$(json "$email")" "$(json "$TRACCAR_ADMIN_PASSWORD")")
      if wget -q -T 15 -O /dev/null --header 'Content-Type: application/json' --post-data "$body" "http://127.0.0.1:${PORT}/api/users"; then
        echo "[railway] Created the administrator '$email'. Its password is the TRACCAR_ADMIN_PASSWORD variable."
      else
        echo "[railway] Could not create the administrator; stopping so the instance doesn't start unclaimed."
        kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
        exit 1
      fi
      ;;
    *) echo "[railway] The database already has users; nothing to create." ;;
  esac
  touch "$marker"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
elif [ -z "${TRACCAR_ADMIN_PASSWORD:-}" ]; then
  echo "[railway] TRACCAR_ADMIN_PASSWORD is empty: no administrator bootstrap. The first account created becomes the administrator."
fi

# shellcheck disable=SC2086
exec "$JAVA" $JAVA_ARGS -jar tracker-server.jar conf/traccar.xml
