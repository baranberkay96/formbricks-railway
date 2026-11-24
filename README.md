# Deploy and Host Formbricks with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/formbricks-62-surveys-postgres-spicedb-h?referralCode=20H68q)

Formbricks is an open-source survey and experience-management platform: link surveys, website and in-app surveys, NPS and feedback analysis. This template runs Formbricks 6.2 with its complete self-hosting stack: the web app, SpiceDB authorization, the Formbricks Hub API and worker, Cube analytics, PostgreSQL 18, Redis and a Railway Bucket for uploads.

## About Hosting Formbricks

Formbricks 6 is more than one container. The Next.js web app keeps its data in PostgreSQL, uses Redis for caching, rate limits and job queues, and asks SpiceDB for every authorization decision. The Hub service stores and processes feedback records (webhooks, enrichments) with a separate worker, and Cube answers the analytics dashboards. All of them share one PostgreSQL server; SpiceDB uses its own database there.

On the first start this template waits for PostgreSQL, applies the migrations of every component, creates the first administrator from your variables before the site answers requests, sets the Bucket's CORS rule for browser uploads and prepares the SpiceDB schema.

## Common Use Cases

- Link surveys and forms you share by URL or QR code
- Website and in-app surveys triggered by user actions through the Formbricks SDK
- NPS, CSAT and product-market-fit tracking with dashboards
- Collecting and analysing feedback from several sources in one place
- A privacy-friendly alternative to Typeform, SurveyMonkey or Qualtrics on your own infrastructure

## Dependencies for Formbricks Hosting

- Formbricks 6.2.2 (official image, pinned by digest)
- SpiceDB 1.57 (AuthZed), Formbricks Hub 0.14.3, Formbricks Cube 1.8.8
- PostgreSQL 18 with pgvector (Railway's `postgres-ssl` image)
- Redis 8.2
- A Railway Bucket for uploaded files

### Deployment Dependencies

- Formbricks source: https://github.com/formbricks/formbricks
- Self-hosting docs: https://formbricks.com/docs/self-hosting/setup/docker
- File uploads (S3) guide: https://formbricks.com/docs/self-hosting/configuration/file-uploads
- SpiceDB: https://authzed.com/docs/spicedb
- Railway Buckets: https://docs.railway.com/guides/storage-buckets

### Implementation Details

| Service | What it does | Public |
|---|---|---|
| Formbricks | Web app and APIs; migrations, first admin, Bucket CORS and SpiceDB schema on start | yes |
| SpiceDB | Authorization graph (gRPC, preshared key) | no |
| Hub | Feedback-record API; runs its own migrations | no |
| Hub Worker | Webhook delivery and enrichment jobs | no |
| Cube | Analytics queries for dashboards | no |
| Postgres | Formbricks, Hub and SpiceDB data | no |
| Redis | Cache, rate limits, job queues | no |
| Bucket | Uploaded images and files (private) | no |

**First login**

1. Enter your e-mail in `ADMIN_EMAIL` when you deploy.
2. Wait for the first deploy (migrations take a few minutes), then open the **Formbricks** URL.
3. Log in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` from the Formbricks service's Variables tab, then create your organization.

The instance is closed: there is no public sign-up, and nobody can claim the setup wizard before you. Add teammates under Organization settings > Members.

**E-mail.** Formbricks sends invitations, password resets and notifications over SMTP, which Railway allows only on the Pro plan. Without SMTP the template disables e-mail verification and password reset, so logins work; set `MAIL_FROM` and `SMTP_*` on Pro to enable e-mail.

**Custom domain.** Add it to the Formbricks service and set `WEBAPP_URL` to `https://{your-domain}`, then redeploy.

**Scaling and versions.** Images are pinned by digest (Formbricks and Cube in `services/*/Dockerfile`, Hub in the template, SpiceDB in `services/spicedb/Dockerfile`). To upgrade, follow the Formbricks release notes, back up Postgres, move the images to the matching release and redeploy; migrations run on start. Hub and Hub Worker must use the same image.

**Resources.** Measured idle on Railway: Formbricks 0.5–0.72 GB, Postgres 0.19 GB, Cube 0.09 GB, SpiceDB, Redis, Hub and Hub Worker under 0.05 GB each; about 1.1 GB in total, roughly $12–25 per month. The web service can pass Trial's 1 GB limit under load, so Hobby is recommended.

**License.** Formbricks' core is AGPL-3.0; code in `apps/web/modules/ee` is under the Formbricks Enterprise license and its features need a license key (the free community features work without one). SpiceDB and Hub are Apache-2.0. This is a community template; it is not affiliated with Formbricks GmbH.

### Why Deploy Formbricks on Railway?

Railway runs the whole Formbricks 6 stack, its database, Redis and file storage in one project with private networking and HTTPS. You get the production layout upstream ships for Docker in one click, with the first admin created for you, and you can add a domain or scale from the dashboard.
