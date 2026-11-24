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

i=0
until spicedb datastore migrate head --datastore-engine=postgres --datastore-conn-uri="$SPICEDB_DATASTORE_CONN_URI" --log-format=console; do
  i=$((i + 1))
  [ "$i" -ge 180 ] && { log "datastore migrations still failing after 15 minutes; exiting so Railway restarts the service"; exit 1; }
  log "datastore not ready (attempt $i; the Formbricks service creates the 'spicedb' database); retrying in 5 s"
  sleep 5
done

log "starting SpiceDB (gRPC :50051, metrics :${PORT})"
exec spicedb serve \
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
