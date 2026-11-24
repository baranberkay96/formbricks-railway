# Formbricks 6.2 Surveys (Postgres, SpiceDB, Hub, Cube, S3): composer spec

## Listing

| Field | Value |
|---|---|
| Name | **Formbricks 6.2 Surveys (Postgres, SpiceDB, Hub, Cube, S3)** |
| Description | Open-source surveys and forms with the full v6 stack and Bucket uploads. (72 chars) |
| Category | Analytics |
| Icon | `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/formbricks.svg` |
| Repo | `baranberkay96/formbricks-railway`, roots `/services/web`, `/services/spicedb`, `/services/cube` |

## Base market templates (checked 2026-11-24)

| Code | Deploys | Notes |
|---|---|---|
| `PPDzCd` | 692 | `formbricks:latest` single service, volume uploads, `pgvector:pg17`; no Hub/Cube/SpiceDB (Formbricks 6 refuses to authorize without SpiceDB) |
| `formbricks-survey` | 5 | Hub/Cube/Redis/Bucket with `:latest` images, path-style bucket, no SpiceDB, Cube from a third-party repo |
| `formbricks-surveys` | 3 | Full stack incl. SpiceDB and Valkey from a third-party repo; Hub 0.14.3 pinned |

## Services

| Service | Source | Port | Healthcheck | Volume |
|---|---|---|---|---|
| Formbricks | repo `/services/web` (`FROM ghcr.io/formbricks/formbricks:6.2.2@sha256:b35e7b1f…`) | 3000 public | `/health` (1200 s) | — |
| SpiceDB | repo `/services/spicedb` (SpiceDB 1.57.0 binaries on Alpine 3.22) | 50051 gRPC, 9090 metrics | `/metrics` | — |
| Hub | `ghcr.io/formbricks/hub:0.14.3@sha256:63b85da9…` | 8080 private | `/health` (1800 s) | — |
| Hub Worker | same image, `/app/hub-worker` | — | — | — |
| Cube | repo `/services/cube` (`FROM ghcr.io/formbricks/cube:1.8.8-3@sha256:dbe4b87e…` + config) | 4000 private | `/readyz` | — |
| Postgres | `postgres-ssl:18.6` (pgvector) | 5432 private | — | `/var/lib/postgresql/data` |
| Redis | `redis:8.2.11` | 6379 private | — | `/data` |
| Bucket | Railway Bucket | — | — | — |

## Design

1. **First admin before the site serves (8.37).** Formbricks lets the first visitor of a fresh instance become the bootstrap admin. After the migrations, `railway-web.sh` runs `railway-bootstrap-admin.sql` with psql: while `User` is empty it inserts the admin (`isBootstrapAdmin = bootstrapAdmin`, e-mail verified) and a `credential` account with a bcrypt-12 hash from pgcrypto (`crypt(…, gen_salt('bf', 12))`, the `$2a$` format Formbricks' bcryptjs verifies) and issuer `local:credential`. Once a user exists, Formbricks' own policy denies uninvited sign-up.
2. **SpiceDB** gets a dedicated `spicedb` database (it must not share `public` with Formbricks: Prisma refuses to migrate a non-empty schema). The SpiceDB start script waits for Postgres, creates the database with psql (upstream's `authzed-db-bootstrap` job; the Formbricks start script does the same as a fallback), runs `datastore migrate head`, then serves with the preshared key; pools capped at 10 read / 5 write connections. Formbricks runs `formbricks-authzed upgrade prepare` (upstream's `authzed-initialize`) in the background until it succeeds.
3. **Hub** waits for Formbricks' `/health` (Prisma refuses to migrate a non-empty schema, P3005, so Formbricks must migrate the shared database first, as upstream orders `formbricks-migrate` before `hub-migrate`), then runs goose + river migrations in a retry loop before `hub-api`; Hub Worker waits for Hub's `/health`. Both share the Formbricks database, as in upstream's production compose.
4. **Cube** config files are baked into a thin image (upstream bind-mounts them).
5. **Bucket CORS:** a dependency-free SigV4 `PutBucketCors` (upstream's documented rule) on every start; presigned POST uploads need it. `S3_FORCE_PATH_STYLE=0` (Railway Buckets are virtual-hosted).
6. **Deploy-form values (8.29):** empty optional variables are dropped; bad URLs fall back to the Railway domain; an invalid `ADMIN_EMAIL` becomes `admin@example.com`; an `ADMIN_PASSWORD` outside 8–128 chars fails closed (random password, logged); a short SpiceDB key fails closed.
7. `AUTHZED_SYSTEM_KEY` (`formbricks`) and `PASSWORD_RESET_DISABLED` (`1`) default in the start script; set them as variables to override.
8. **Networking:** Next.js on `HOSTNAME=::`; Go services on `:port` (dual stack); Redis URL with `?family=0`; Postgres clients on the private network use `sslmode=disable` (8.36).

## Improvements over market templates

- The complete Formbricks 6 stack (SpiceDB, Hub, Hub Worker, Cube) instead of a single `:latest` container that cannot authorize on v6.
- Everything pinned by digest; no third-party repos; Railway Bucket with virtual-hosted URLs and CORS set automatically.
- First admin created from variables; no claimable setup wizard.
- Healthchecks on Formbricks, SpiceDB, Hub and Cube; every component waits for Postgres instead of crash-looping.

## Resources

To be measured on the test deploy (see the report).

## Verification checklist

- [ ] All services SUCCESS; `/health` 200 on the public URL.
- [ ] Log in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`; create an organization and a link survey; answer it anonymously; response visible.
- [ ] `/setup` / sign-up refused for strangers.
- [ ] Upload an image in a survey (Bucket), image served.
- [ ] Odd values (short password, bad e-mail) do not fail the deploy.

## Open questions

- SMTP (invitations, password reset) needs Railway Pro; not testable here.
