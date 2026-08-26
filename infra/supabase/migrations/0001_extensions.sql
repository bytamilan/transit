-- Migration 0001_extensions
-- Create the dedicated Transit schema, enable the required extensions, and
-- create the application role used by the Go API / integration tests.
-- All statements are idempotent.

CREATE SCHEMA IF NOT EXISTS transit;
SET LOCAL search_path TO transit, public, extensions, auth;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Application role: not a superuser, not the table owner, so it is subject to
-- RLS. The Go API connects as this role and sets request.jwt.claims per request.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'transit_app') THEN
        CREATE ROLE transit_app WITH LOGIN PASSWORD 'transit_app';
    END IF;
END
$$;

ALTER ROLE transit_app SET search_path TO transit, public, extensions, auth;

GRANT USAGE ON SCHEMA transit TO transit_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
