# Transit

A deployable, agency-agnostic **land transport data platform**. Any transport
authority — national, state, or municipal — can self-host Transit and get a
driver app, a rider app, a data portal + admin console, and standards-compliant
GTFS / GTFS-Realtime / GBFS feeds, all driven from one agency-config document.

Inspired by Singapore's LTA DataMall, but agency-agnostic: nothing country-,
currency-, language-, timezone-, map-provider-, fare-rule- or vendor-specific
exists outside an adapter or a config file. **GTFS is the canonical internal
model** — every upstream adapter normalises into it, every output serialises
out of it.

## Stack

| Layer | Choice |
|---|---|
| Apps | Flutter — Riverpod + GoRouter + freezed |
| Portal | Next.js App Router + Tailwind |
| Backend | Go — chi, pgx/v5, sqlc, distroless container |
| DB / Auth / Realtime | Supabase Postgres (+ PostGIS, pg_cron), Supabase Auth with JWT custom-claims hook, Supabase Realtime |
| Maps | Pluggable — MapLibre + OSM/Protomaps default, Google optional |
| Tooling | Melos + go.work + pnpm |

## Where to go next

- **[Features](features.md)** — what each component does.
- **Apps** — screenshots and a description of the driver app, rider app, and
  portal.
- **Packages** — the shared Dart packages (`transit_core`, `transit_maps`, …)
  and what each is for.
- **API Reference** — the full REST API, generated from
  `contracts/openapi.yaml`.
- **Wiki** — architecture decision records, onboarding, and operational
  runbooks.

## Quick start

```sh
cp .env.example .env
make dev        # boots Postgres (PostGIS) + API  →  http://localhost:8080/healthz
make test       # Dart, Go and portal suites
make lint
```
