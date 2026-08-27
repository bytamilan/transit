# Migration runbook

Transit's migrations live in `infra/supabase/migrations/`, applied in
filename order (`0001_...` through `0016_...` as of Phase 12) by
`services/api/cmd/migrate`, tracked in a `transit.schema_migrations` table.

## Rules every migration in this repo follows

1. **Forward-only.** There is no `down` migration. A mistake is fixed by a
   new migration that corrects it, not by editing or reverting a merged
   one — the same reason git history isn't rewritten after a push. If a
   migration hasn't been applied anywhere yet (still in review), editing it
   in place is fine; once it's merged to `main`, treat it as immutable.
2. **Idempotent.** Every `CREATE TABLE` is `IF NOT EXISTS`, every function
   is `CREATE OR REPLACE`, every index is `IF NOT EXISTS`. Re-running
   `make db.migrate` against an already-migrated database is always safe —
   `cmd/migrate` also tracks which migrations have already run and skips
   them, but the SQL itself is written to tolerate a second run regardless.
3. **`SET LOCAL search_path TO transit, public, extensions, auth`** at the
   top of every migration file (per ADR 0001) — Transit's tables live in
   the `transit` schema, not `public`.
4. **Every new SECURITY DEFINER function ends with an explicit `GRANT
   EXECUTE ... TO transit_app`**, and every migration ends with the
   standard blanket grants block:
   ```sql
   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
   ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
   GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
   ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
   ```
   Forgetting this means `transit_app` (the role the Go API connects as)
   gets a permission error the first time a handler calls the new function
   — an easy, obvious failure mode, but worth checking for explicitly in
   review since it only shows up at runtime, not at migration-apply time.

## Applying migrations

```
make db.migrate DB_URL=postgres://...   # or DATABASE_URL directly, see Makefile
```

`cmd/migrate` also supports `reset` (drop and recreate — **local/staging
only**, never point this at a database with real data) via `make db.reset`.

In CI (`.github/workflows/ci.yml`'s `go` job) migrations run against a
throwaway `supabase/postgres` service container on every push/PR — this is
the closest thing this repo has to a migration smoke test, since no branch
in this session's history was ever actually applied to a live database
outside that CI job (see `docs/PHASE_PLAN.md`'s repeated "no Docker this
session" notes).

## Writing a new migration

1. Next filename: `<four-digit-number>_<short-description>.sql`, one more
   than the highest existing number.
2. Start from the closest existing migration that does something similar
   (e.g. a new admin-write table + SECURITY DEFINER CRUD functions →
   `0015_planner_and_alerts.sql`'s `service_alerts` table is the most
   recent template for that shape) rather than writing RLS policy syntax
   from scratch.
3. If the migration adds a table other roles need to read/write, follow
   the RLS pattern already established: `ENABLE ROW LEVEL SECURITY` +
   `FORCE ROW LEVEL SECURITY`, a `_select`/`_write`/`_update`/`_delete`
   policy set keyed on `current_agency_id()`/`current_user_role()`. RLS
   here is defense-in-depth — the actual authorization boundary is
   `internal/httpapi/rbac` in Go, since the API always connects as
   `transit_app` rather than per-user JWT (see
   `infra/supabase/migrations/0006_audit_log_writer.sql`'s comment for
   why). Both layers matter: RLS is what stops a direct-DB-access bug or a
   future service that *does* connect per-user from becoming a
   cross-tenant leak.
4. Run it against a real database before merging if at all possible — this
   session never could (no Docker), which is exactly the gap CI now closes
   (see above) for every PR going forward.

## Rolling back a bad migration once it's live

There's no automated rollback. The procedure is:
1. Write a new forward migration that reverses the change (drop the
   column/table/function the bad migration added, or restore the previous
   function definition via `CREATE OR REPLACE`).
2. If data was already written under the bad schema and needs to survive
   the rollback, that migration also needs a data-migration step — write
   and test it against a copy of production data first, not directly
   against production.
3. For anything involving data loss risk, restore from backup instead of
   trying to migrate out of the mistake — see `backup-restore.md`.
