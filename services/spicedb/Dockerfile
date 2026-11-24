# SpiceDB 1.57.0 binaries from the official (distroless) image on a small Alpine base, so a start
# script can wait for Postgres and run the datastore migrations before serving.
ARG SPICEDB_IMAGE=authzed/spicedb:v1.57.0@sha256:a170d372c9f6b921bb6849064df6ca3566dd5b174882c1a2c4300c2ae1d60efd
FROM ${SPICEDB_IMAGE} AS spicedb

FROM alpine:3.22@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f
COPY --from=spicedb /usr/local/bin/spicedb /usr/local/bin/spicedb
COPY --chmod=0755 railway-spicedb.sh /usr/local/bin/railway-spicedb.sh
RUN adduser -D -H -u 10001 spicedb
USER spicedb
ENV PORT=9090
ENTRYPOINT ["/usr/local/bin/railway-spicedb.sh"]
