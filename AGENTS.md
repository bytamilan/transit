# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project overview

Transit is a deployable, agency-agnostic land transport data platform: Flutter
driver and rider apps, a Next.js data portal/admin console, and a Go backend
serving GTFS / GTFS-Realtime / GBFS feeds. **GTFS is the canonical internal
model** — every upstream adapter normalises into it, every output serialises
out of it.

Source-of-truth docs (read before non-trivial work):

- `internal-docs/BUILD_PROMPT.md` — engineering brief: tenancy, roles &
  security, adapters, data model, non-negotiables.
- `internal-docs/PHASE_PLAN.md` — execution plan (phases, tasks, gates).

## Repository layout

```
apps/driver_app   Flutter — mounted driver terminal (zero-touch GPS tracking, offline ping queue)
apps/rider_app    Flutter — live map, arrivals, trip planner (mobile + web)
apps/portal       Next.js App Router + Tailwind — open-data portal + admin console
packages/         Shared Dart packages: transit_core, transit_api_client, transit_design,
                  transit_maps, transit_telemetry
services/api      Go backend: adapters, ingest, gtfs, httpapi, store, tracking, dispatch,
                  fusion, planner (chi, pgx/v5, sqlc, distroless container)
contracts/        openapi.yaml — single source of truth for the REST API
infra/supabase/   Postgres migrations, RLS policies, seed fixtures
deploy/           compose, helm, terraform, observability
docs-site/        MkDocs documentation site
internal-docs/    BUILD_PROMPT.md, PHASE_PLAN.md, ADRs, runbooks
```

## Toolchain

- Go via `go.work` (module: `services/api`)
- Dart/Flutter via Melos (`apps/driver_app`, `apps/rider_app`, `packages/**`)
- Node via pnpm workspace (`apps/portal`, `docs-site/scripts`)

## Common commands

- `make dev` — boot core local stack (Postgres + PostGIS + API →
  `http://localhost:8080/healthz`); creates `.env` from `.env.example` if
  missing
- `make dev-full` — full stack including Supabase Auth, REST, Realtime
- `make test` — Go short tests, Flutter tests for both apps, portal
  typecheck + build
- `make lint` — `go vet`, `melos run lint` (dart analyze), portal lint
- `make db.test` — integration tests against a throwaway PostGIS container
  (requires Docker)
- `make gen` / `make gen-check` — regenerate server & client types from
  `contracts/openapi.yaml` (oapi-codegen + openapi-generator); keep generated
  code in sync when the contract changes
- `make portal.dev` — portal dev server (needs `apps/portal/.env.local`)
- `make docs` / `make docs-serve` — build/serve the docs site

Run narrower suites while iterating, e.g. `cd services/api && go test ./internal/...`,
`cd apps/rider_app && flutter test`, `pnpm -C apps/portal typecheck`.

## Hard rules (from the build brief)

- No agency-, country-, currency-, language-, timezone-, map-provider-,
  fare-rule- or vendor-specific logic outside an adapter or config file.
- Roles never read from `user_metadata` (use the JWT custom-claims hook / DB).
- Stop events are recomputed server-side; raw driver pings are never exposed
  publicly.
- `contracts/openapi.yaml` is the single source of truth for the REST API —
  change it first, then regenerate with `make gen`.

## Conventions

- Flutter apps: Riverpod + GoRouter + freezed; shared code goes in
  `packages/`, not duplicated between apps.
- Go backend: chi router, pgx/v5 with sqlc-generated queries; migrations live
  in `infra/supabase/migrations` and are applied via `cmd/migrate`.
- Portal: Next.js App Router + Tailwind.
- Tests: mirror the suites wired into `make test`; Flutter golden tests are
  tagged `golden` and excluded from the default run (`make docs-goldens`
  regenerates them).
