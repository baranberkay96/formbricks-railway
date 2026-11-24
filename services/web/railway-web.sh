#!/bin/sh
# Railway start script for the Formbricks web app.
# 1. repairs deploy-form values that would stop the boot (STANDARD 8.29)
# 2. waits for Postgres, creates the SpiceDB database, applies migrations and the SAML database
# 3. creates the first admin from ADMIN_EMAIL / ADMIN_PASSWORD before the server listens (8.37)
# 4. sets the Bucket CORS rule, applies the SpiceDB schema in the background, starts Next.js
set -u
cd /home/nextjs
export NODE_ENV=production
log() { echo "[railway-formbricks] $*"; }

# Formbricks' env schema rejects several empty strings; drop variables the deploy form left empty.
for var in $(env | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=$/\1/p'); do unset "$var"; done

export HOSTNAME="::"
# Defaults kept out of the deploy form: SpiceDB object id and no password-reset e-mails without SMTP.
export AUTHZED_SYSTEM_KEY="${AUTHZED_SYSTEM_KEY:-formbricks}"
export PASSWORD_RESET_DISABLED="${PASSWORD_RESET_DISABLED:-1}"
case "${PORT:-}" in ''|*[!0-9]*) export PORT=3000 ;; esac
for url_var in WEBAPP_URL NEXTAUTH_URL BETTER_AUTH_URL; do
  eval "value=\${$url_var:-}"
  case "$value" in
    http://?*|https://?*) ;;
    *) eval "export $url_var=https://${RAILWAY_PUBLIC_DOMAIN:-localhost}"; log "WARNING: $url_var is not a URL; using https://${RAILWAY_PUBLIC_DOMAIN:-localhost}" ;;
  esac
done

ADMIN_EMAIL="$(printf '%s' "${ADMIN_EMAIL:-}" | tr -d ' \t' | tr 'A-Z' 'a-z')"
if ! printf '%s' "$ADMIN_EMAIL" | grep -Eq '^[^@ ]+@[^@ ]+\.[^@ ]+$'; then
  log "WARNING: ADMIN_EMAIL '${ADMIN_EMAIL}' is not an e-mail address; the first admin is created as admin@example.com"
  ADMIN_EMAIL=admin@example.com
fi
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
if [ "${#ADMIN_PASSWORD}" -lt 8 ] || [ "${#ADMIN_PASSWORD}" -gt 128 ]; then
  ADMIN_PASSWORD="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  log "WARNING: ADMIN_PASSWORD must be 8-128 characters. A first admin (if one is created now) gets a random password nobody knows: set a valid ADMIN_PASSWORD, delete the Postgres volume or reset the user, and redeploy."
fi

# psql cannot parse Prisma-only URL parameters (schema=, connection_limit=).
PSQL_URL="${DATABASE_URL%%\?*}?sslmode=disable"

wait_for_db() {
  i=0
  until psql "$PSQL_URL" -qtAc 'SELECT 1' >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -ge 180 ] && { log "Postgres unreachable for 15 minutes; exiting so Railway restarts the service"; exit 1; }
    log "waiting for Postgres ($i)"
    sleep 5
  done
}

retry() {
  name="$1"; shift
  i=0
  until "$@"; do
    i=$((i + 1))
    [ "$i" -ge 30 ] && { log "$name kept failing; exiting so Railway restarts the service"; exit 1; }
    log "$name failed (attempt $i); retrying in 10 s"
    sleep 10
  done
}

wait_for_db
if [ "$(psql "$PSQL_URL" -qtAc "SELECT 1 FROM pg_database WHERE datname = 'spicedb'")" != "1" ]; then
  psql "$PSQL_URL" -qc 'CREATE DATABASE spicedb' && log "created database 'spicedb' for SpiceDB"
fi

node /home/nextjs/validate-env.mjs --server || log "WARNING: environment validation reported problems (see above)"
retry "database migration" node packages/database/dist/scripts/apply-migrations.js
retry "SAML database setup" node packages/database/dist/scripts/create-saml-database.js

created="$(psql "$PSQL_URL" -qtA -v admin_email="$ADMIN_EMAIL" -v admin_password="$ADMIN_PASSWORD" \
  -v admin_name="${ADMIN_NAME:-Admin}" -f /home/nextjs/railway-bootstrap-admin.sql 2>&1)" || log "WARNING: first-admin bootstrap failed: $created"
case "$created" in *created*) log "first admin created: $ADMIN_EMAIL (password: ADMIN_PASSWORD variable)" ;; esac

node /home/nextjs/railway-bucket-cors.mjs || log "WARNING: could not set the Bucket CORS rule; browser file uploads may fail until it is set"

(
  i=0
  until formbricks-authzed upgrade prepare >/tmp/authzed-prepare.log 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 90 ]; then
      log "SpiceDB schema preparation still failing after 15 minutes:"; tail -n 20 /tmp/authzed-prepare.log; exit 0
    fi
    sleep 10
  done
  log "SpiceDB schema and relationships prepared"
) &

log "starting Formbricks on [::]:${PORT}"
exec node apps/web/online-server.js
