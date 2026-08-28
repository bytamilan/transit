# ADR 0001: Supabase self-host image set (Phase 1)

## Status
Accepted — Phase 1

## Context
Transit needs a multi-tenant, self-hostable Postgres with auth, REST and realtime.
Supabase open-sources these as separate containers. We must pin the image set so
local development, CI and self-hosted deployments run the same bits.

## Decision
Use the Supabase self-host Postgres image for the database and upstream
Supabase/PostgREST images for the optional auth/rest/realtime services:

| Service | Image | Role in Transit |
|---|---|---|
| Database | `supabase/postgres:15.8.1.044` | Postgres + PostGIS + pg_cron + bundled extensions |
| Auth | `supabase/gotrue:v2.167.0` | JWT issuer for apps and portal |
| REST | `postgrest/postgrest:v12.2.3` | Auto-generated REST over the Transit schema |
| Realtime | `supabase/realtime:v2.34.2` | Postgres-change subscriptions for the dispatch board |

The core `make dev` target starts only Postgres and the Go API. Auth, REST and
Realtime are behind the `supabase` compose profile and booted with `make dev-full`.
They are present in the local topology from Phase 1, but the custom-claims hook
and the `anon`/`authenticated` database roles are intentionally completed in
Phase 2 so the services do not fail on a partially-wired auth model.

## Consequences
- `make dev` remains fast and deterministic. `make dev-full` exercises the full
  Supabase topology.
- Image digests are not pinned yet; this ADR records the tag decisions and will
  be updated once the digest set is verified in CI.
- Auth, REST and Realtime depend on Postgres being healthy before they start.
- The Go API and the integration-test harness connect as a non-superuser
  (`transit_app`) so Row Level Security is actually enforced. Migrations run as
  the Postgres database owner.
- All Transit application tables live in a dedicated `transit` schema. Migration
  files, seed scripts, and connection strings set `search_path` to
  `transit,public,extensions,auth`. The `schema_migrations` tracking table also
  lives in `transit`.

## Risks
- Image drift between local dev and CI if digests are not pinned soon. Mitigated
  by recording the chosen tags here and tracking updates in the same file.
- Realtime creates a `_realtime` schema and needs `supabase_admin` credentials;
  this is handled by the official Supabase Postgres image out of the box.
