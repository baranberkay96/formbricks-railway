-- Creates the first Formbricks administrator from Railway variables, before the web server listens.
-- Formbricks lets the first visitor of a fresh instance sign up as the bootstrap admin; creating the
-- account here closes that window (STANDARD 8.37). Runs only while the User table is empty.
-- Password hash: bcrypt cost 12 ($2a$), the format Formbricks' verifySecret (bcryptjs) accepts.
\set ON_ERROR_STOP on
CREATE EXTENSION IF NOT EXISTS pgcrypto;
WITH new_user AS (
  INSERT INTO "User" (id, created_at, updated_at, name, email, email_verified, "identityProvider", locale, "isBootstrapAdmin")
  SELECT 'rw' || substr(md5(random()::text || clock_timestamp()::text), 1, 23), now(), now(),
         :'admin_name', lower(:'admin_email'), true, 'email'::"IdentityProvider", 'en-US', 'bootstrapAdmin'::"BootstrapAdminMarker"
  WHERE NOT EXISTS (SELECT 1 FROM "User")
  RETURNING id
)
INSERT INTO "Account" (id, created_at, updated_at, "userId", provider, "providerAccountId", password, issuer)
SELECT 'ra' || substr(md5(random()::text || clock_timestamp()::text), 1, 23), now(), now(),
       id, 'credential', id, crypt(:'admin_password', gen_salt('bf', 12)), 'local:credential'
FROM new_user
RETURNING 'created' AS bootstrap_admin;
