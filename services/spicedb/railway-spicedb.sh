#!/bin/sh
# Railway start script for SpiceDB (Formbricks' authorization engine).
# Waits for Postgres, applies datastore migrations, then serves gRPC on [::]:50051 (private only)
# and metrics/health on [::]:$PORT (Railway healthcheck).
set -u
log() { echo "[railway-spicedb] $*"; }

case "${PORT:-}" in ''|*[!0-9]*) PORT=9090 ;; esac
KEY="${SPICEDB_GRPC_PRESHARED_KEY:-}"
if [ "${#KEY}" -lt 16 ]; then
  # Fail closed without failing the deploy: Formbricks cannot authenticate until a valid key is set.
  KEY="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  log "WARNING: SPICEDB_GRPC_PRESHARED_KEY is missing or shorter than 16 characters; using a random key. Set the same 16+ character value here and as AUTHZED_TOKEN on Formbricks."
fi
unset SPICEDB_GRPC_PRESHARED_KEY

# Create the dedicated database (upstream's authzed-db-bootstrap job) through the default database.
ADMIN_URL="${SPICEDB_ADMIN_DATABASE_URL:-}"
i=0
until [ -z "$ADMIN_URL" ] || psql "$ADMIN_URL" -qtAc 'SELECT 1' >/dev/null 2>&1; do
  i=$((i + 1)); [ "$i" -ge 360 ] && { log "Postgres unreachable for 30 minutes; exiting so Railway restarts the service"; exit 1; }
  log "waiting for Postgres ($i)"; sleep 5
done
if [ -n "$ADMIN_URL" ] && [ "$(psql "$ADMIN_URL" -qtAc "SELECT 1 FROM pg_database WHERE datname = 'spicedb'")" != "1" ]; then
  psql "$ADMIN_URL" -qc 'CREATE DATABASE spicedb' && log "created database 'spicedb'"
fi

i=0
until spicedb datastore migrate head --datastore-engine=postgres --datastore-conn-uri="$SPICEDB_DATASTORE_CONN_URI" --log-format=console --skip-release-check=true; do
  i=$((i + 1))
  [ "$i" -ge 180 ] && { log "datastore migrations still failing after 15 minutes; exiting so Railway restarts the service"; exit 1; }
  log "datastore not ready (attempt $i); retrying in 5 s"
  sleep 5
done

log "starting SpiceDB (gRPC :50051, metrics :${PORT})"
exec spicedb serve \
  --skip-release-check=true \
  --grpc-preshared-key="$KEY" \
  --grpc-addr=":50051" \
  --metrics-addr=":${PORT}" \
  --http-enabled=false \
  --datastore-engine=postgres \
  --datastore-conn-uri="$SPICEDB_DATASTORE_CONN_URI" \
  --datastore-conn-pool-read-max-open=10 \
  --datastore-conn-pool-write-max-open=5 \
  --telemetry-endpoint="" \
  --log-format=json
