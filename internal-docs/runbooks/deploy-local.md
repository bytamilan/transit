# Deploying locally

Everything needed to run Transit on a single developer machine, via
`deploy/compose/compose.yaml`. This is the fastest path to a working stack
and the one CI itself uses to smoke-test migrations (`ci.yml`'s `go` job)
and validate the compose file parses (`ci.yml`'s `compose-config` job).

## Prerequisites

- Docker + Docker Compose v2 (`docker compose`, not the standalone
  `docker-compose`)
- Go 1.26+ (only if building/running the Go binaries outside their
  containers, e.g. `make ingest`, `make db.migrate`)
- Flutter 3.x (only for `apps/driver_app` / `apps/rider_app`)
- Node 20+ and pnpm (`corepack enable` picks up the pinned pnpm version) —
  only for `apps/portal`

Nothing else needs installing to run `make dev` — Postgres, the API, and
the background workers all run in containers built from this repo.

## 1. Core stack: Postgres + API

```sh
git clone <this repo>
cd transit
cp .env.example .env
make dev
```

`make dev` runs `docker compose -f deploy/compose/compose.yaml --env-file
.env up --build`, which brings up:

| Service | Image / build | Port | Purpose |
|---|---|---|---|
| `db` | `supabase/postgres:15.8.1.044` | `5432` | Postgres + PostGIS + pg_cron |
| `api` | built from `services/api/Dockerfile`, `CMD ["/server"]` | `8080` | Public/admin REST API (`/healthz`, `/readyz`) |
| `ingestor` | same image, `command: ["/ingestor"]` | — | Polls configured feeds (`gtfs_static`/`gtfs_rt`) on `RELOAD_INTERVAL` (default `5m`) |
| `tracker` | same image, `command: ["/tracker"]` | — | Reprocesses driver ping traces into `stop_events`/`vehicle_trips` every `TRACKER_TICK_INTERVAL` (default `15s`); purges pings past `VEHICLE_PINGS_RETENTION_DAYS` (default `7`) |
| `exporter` | same image, `command: ["/exporter"]` | `8090` | Rebuilds `GTFS.zip` per agency every `EXPORT_INTERVAL` (default `15m`); serves it and a GTFS-RT ServiceAlerts stub |

`api`, `ingestor`, `tracker` and `exporter` are all **the same container
image** (`services/api/Dockerfile` builds all four binaries into one
distroless image); only the `command:` differs. This is the same pattern
`deploy/helm/transit` uses in Kubernetes, so what you observe locally
(behavior, env vars, restart semantics) carries over to the cluster.

Confirm it's up:

```sh
curl localhost:8080/healthz
```

`ingestor`/`tracker`/`exporter` have `restart: on-failure` — if the schema
isn't migrated yet (next step), they'll crash-loop harmlessly until
migrations are applied, then recover on their own restart.

## 2. Apply migrations and seed demo data

```sh
make db.migrate   # applies infra/supabase/migrations/*.sql in order
make db.seed      # loads infra/supabase/seed/demo_agencies.sql (idempotent)
```

This creates the `demo-metro` fixture agency. Confirm:

```sh
curl localhost:8080/v0/agencies/demo-metro
```

`make db.migrate` targets `DATABASE_URL` derived from `.env`'s
`POSTGRES_PASSWORD`/`POSTGRES_DB` (see the `Makefile`'s `DB_URL` default) —
override with `DATABASE_URL=... make db.migrate` to point it elsewhere.
`make db.reset` drops and recreates the schema — **local/staging only**,
never point it at a database with real data.

## 3. Full stack: add Supabase Auth, REST, Realtime

The core stack above is enough for most API/backend work. If you're
touching auth flows, RLS, or the portal's `@supabase/ssr` login, bring up
the full stack instead:

```sh
make dev-full
```

This adds four more services behind Compose's `supabase` profile:

| Service | Image | Port | Notes |
|---|---|---|---|
| `db-init` | `supabase/postgres:15.8.1.044` | — | One-shot: sets passwords Supabase's own init scripts don't, creates the `_realtime` schema. Runs once, then exits. |
| `auth` | `supabase/gotrue:v2.167.0` | `9999` | JWT issuer; wired to the `custom_access_token_hook` (ADR 0003) for role claims |
| `rest` | `postgrest/postgrest:v12.2.3` | `3000` (admin: `3001`) | Direct REST/SQL over the `transit` schema |
| `realtime` | `supabase/realtime:v2.34.2` | `4000` | Postgres change feed — no active consumers yet, healthcheck only |

`make dev` and `make dev-full` **share the same `db` volume** (`db_data`)
— you don't lose data switching between them, but the Supabase services
won't work correctly until `db-init` has run at least once (it runs
automatically as part of `make dev-full`).

## 4. Run the Flutter apps against the local stack

```sh
cd apps/driver_app   # or apps/rider_app
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<from make dev-full's auth service, or the portal's .env.local>
```

If `--dart-define=API_BASE_URL` is omitted, both apps default to
`http://localhost:8080` (`apps/rider_app/lib/providers/api_provider.dart`),
so it's optional for the common case of pointing at the local stack.

## 5. Run the portal against the local stack

```sh
cp apps/portal/.env.example apps/portal/.env.local
# fill in NEXT_PUBLIC_SUPABASE_ANON_KEY from make dev-full's auth service
make portal.install
make portal.dev              # http://localhost:3000
```

`apps/portal/.env.example` — what to fill in:

```
NEXT_PUBLIC_SUPABASE_URL=http://localhost:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
NEXT_PUBLIC_EXPORTER_BASE_URL=http://localhost:8090
```

The portal talks to `services/api` directly with the signed-in user's
access token — it never connects to Postgres itself, so it doesn't need
`DATABASE_URL`.

## 6. Everyday commands

```sh
make logs      # tail every compose service's logs
make down      # stop the stack AND drop volumes (fresh Postgres next `make dev`)
make lint      # go vet + melos lint (Dart) + pnpm portal lint
make test      # go test -short + flutter test (both apps) + portal typecheck/build
make db.test   # spins up a throwaway Postgres on :5433, migrates, seeds, runs Go integration tests, tears down — isolated from the make dev stack
```

`make down` is destructive to local data (`docker compose down -v`) — if
you have local-only data you care about, back it up first (see
[Backup & restore](backup-restore.md)'s local `pg_dump` command) rather
than running `make down`.

## Troubleshooting

- **`ingestor`/`tracker`/`exporter` keep restarting**: almost always means
  migrations haven't been applied yet. Run `make db.migrate`, then
  `docker compose -f deploy/compose/compose.yaml --env-file .env restart
  ingestor tracker exporter` if they don't recover on their own.
- **Port already in use**: another local Postgres (5432), or a leftover
  `make db.test` container on 5433 that didn't get torn down
  (`docker stop transit-test-db`).
- **`rest`/`realtime` unhealthy under `make dev-full`**: confirm `db-init`
  actually completed (`docker compose -f deploy/compose/compose.yaml
  --env-file .env logs db-init`) — both depend on it having set passwords
  and created the `_realtime` schema first.
- **Portal can't reach Supabase Auth**: confirm `apps/portal/.env.local`
  exists (not just `.env.example`) and `NEXT_PUBLIC_SUPABASE_ANON_KEY` is
  filled in from the running `auth` service.

## Next steps

- [Deploying the dev/staging cloud environment](deploy-dev-staging.md)
- [Deploying to production](deploy-production.md)
- [Onboarding a new agency](../onboarding/README.md) — everything past "the
  stack is running," including agency config and getting real transit data in
