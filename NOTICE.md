# Notice

This repository is a Railway template package for Formbricks. Our own files (`services/web/railway-*`, `services/spicedb/*`, Dockerfiles, docs) are MIT-licensed.

| Component | License | Used as |
|---|---|---|
| Formbricks 6.2.2 | AGPL-3.0 (core); Formbricks Enterprise license for `apps/web/modules/ee`; MIT for the SDK packages | Official image `ghcr.io/formbricks/formbricks:6.2.2@sha256:b35e7b1f…`, extended with our start script and `postgresql-client` |
| Formbricks Cube config (`services/cube/cube.js`, `services/cube/model/FeedbackRecords.js`) | AGPL-3.0, Copyright (c) 2024 Formbricks GmbH | Copied unchanged from `docker/cube/` at tag `6.2.2` of https://github.com/formbricks/formbricks |
| Formbricks Cube image 1.8.8-3 (Cube.js) | Apache-2.0 | `ghcr.io/formbricks/cube:1.8.8-3@sha256:dbe4b87e…` |
| Formbricks Hub 0.14.3 | Apache-2.0 | `ghcr.io/formbricks/hub:0.14.3@sha256:63b85da9…` |
| SpiceDB 1.57.0 | Apache-2.0 (AuthZed) | binaries from `authzed/spicedb:v1.57.0@sha256:a170d372…` on Alpine 3.22 |
| PostgreSQL 18 | PostgreSQL License | `ghcr.io/railwayapp-templates/postgres-ssl:18.6` (Railway) |
| Redis 8.2 | RSALv2 / SSPLv1 / AGPLv3 | `redis:8.2.11` (official image, unmodified) |

The AGPL-3.0 applies to the Formbricks code inside the image and to the two Cube files above; their source is available at the upstream repository and tag listed. The Formbricks Enterprise features are not unlocked by this template.

## Upstream files checked

- `docker/docker-compose.yml`, `docker/README.md`, `apps/web/Dockerfile`, `apps/web/scripts/docker/next-start.sh` at tag `6.2.2`
- `apps/web/lib/env.ts`, `apps/web/modules/auth/lib/auth.ts`, `apps/web/modules/auth/lib/signup-policy.ts`, `apps/web/lib/instance/service.ts`, `packages/database/schema/main.prisma` (first-admin bootstrap)
- `docs/self-hosting/configuration/file-uploads.mdx` (S3 CORS), `docs/self-hosting/configuration/authzed-operations.mdx`
- Formbricks Hub `Dockerfile` and `internal/config/config.go` at `0.14.3`; SpiceDB `Dockerfile` and `docs/spicedb.md` at `v1.57.0`

Formbricks is a trademark of Formbricks GmbH. This community template is not affiliated with or endorsed by Formbricks GmbH.
