# Formbricks 6.2.2 (official image, pinned by digest) plus a Railway start script, a psql client for the
# first-admin bootstrap and the SpiceDB database, and a dependency-free Bucket CORS helper.
ARG FORMBRICKS_IMAGE=ghcr.io/formbricks/formbricks:6.2.2@sha256:b35e7b1fa7d001379282b5c0ed37daf740da6ca4d170593d52052b9aaed8ed04
FROM ${FORMBRICKS_IMAGE}
USER root
RUN apk add --no-cache postgresql-client
COPY --chmod=0755 railway-web.sh /home/nextjs/railway-web.sh
COPY --chmod=0644 railway-bootstrap-admin.sql railway-bucket-cors.mjs /home/nextjs/
USER nextjs
ENV PORT=3000
CMD ["/home/nextjs/railway-web.sh"]
