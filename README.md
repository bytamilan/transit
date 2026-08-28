# Transit

A deployable, agency-agnostic **land transport data platform**. Any transport
authority — national, state, or municipal — can self-host Transit and get:

| Component | What it is |
|---|---|
| **Driver App** (Flutter) | Mounted, always-on, near-zero-interaction terminal. The phone *is* the AVL system — zero-touch GPS tracking, auto trip start/end, offline-first ping queue. |
| **Rider App** (Flutter, mobile + web) | Live vehicle map, nearby-stop arrivals, route shapes, multimodal trip planner, offline timetable fallback. |
| **Data Portal + Admin Console** (Next.js) | Open-data portal (datasets, API keys, docs, usage) plus the operational back office: fleet, routes, drivers, duty assignment, live dispatch board. |
| **Standards-compliant feeds** | Publishable `GTFS.zip` and GTFS-Realtime (TripUpdates, VehiclePositions, ServiceAlerts), plus GBFS — consumable by Google Maps, Moovit, Citymapper and OpenTripPlanner with zero integration work. |

**GTFS is the canonical internal model** — every upstream adapter normalises
into it, every output serialises out of it. Nothing country-, currency-,
language-, timezone-, map-provider-, fare-rule- or vendor-specific exists
outside an adapter or a config file.

## The docs

- [`docs/BUILD_PROMPT.md`](docs/BUILD_PROMPT.md) — the complete engineering
  brief: tenancy, roles & security, driver-app behaviour, adapters, data
  model, non-negotiables. **The source of truth — read it first.**
- [`docs/PHASE_PLAN.md`](docs/PHASE_PLAN.md) — the detailed execution plan:
  all 13 phases broken into tasks, deliverables, gates, dependencies, risks
  and milestones.
- The full documentation site (features, app screenshots, package
  references, API reference, wiki) is published at
  https://bytamilan.github.io/transit/ via GitHub Pages — see `docs-site/`
  in this repo, or run `make docs-serve` for a local copy.

## Stack

| Layer | Choice |
|---|---|
| Apps | Flutter — Riverpod + GoRouter + freezed |
| Portal | Next.js App Router + Tailwind |
| Backend | Go — chi, pgx/v5, sqlc, distroless container |
| DB / Auth / Realtime | Supabase Postgres (+ PostGIS, pg_cron), Supabase Auth with JWT custom-claims hook, Supabase Realtime |
| Maps | Pluggable — MapLibre + OSM/Protomaps default, Google optional |
| Tooling | Melos + go.work + pnpm |

## Repository layout

```
apps/        driver_app · rider_app · portal (Next.js)
packages/    transit_core · transit_api_client · transit_design · transit_maps · transit_telemetry
services/api/  Go backend: adapters, ingest, gtfs, httpapi, store, tracking, dispatch, fusion, planner
contracts/   openapi.yaml — single source of truth for the REST API
infra/       supabase migrations & RLS policies
deploy/      compose · helm · terraform
docs/        adr · onboarding · BUILD_PROMPT.md · PHASE_PLAN.md
```

## Quick start

```sh
cp .env.example .env
make dev        # boots Postgres (PostGIS) + API  →  http://localhost:8080/healthz
make test       # Dart, Go and portal suites
make lint
```

Local users:
- Admin console: demo-admin@transit.local
- Password: DemoAdmin123!
- Role: agency_admin


## Contributing

Work follows the phase plan in [`docs/PHASE_PLAN.md`](docs/PHASE_PLAN.md).
Hard rules (build brief §0) apply to every PR — in particular: no
agency-specific hardcoding, roles never read from `user_metadata`, stop events
recomputed server-side, and raw driver pings never exposed publicly.

## License

[MIT](LICENSE). Per-agency data licensing (SPDX, attribution, terms) is
configuration, not code — see §10 of the build brief.
