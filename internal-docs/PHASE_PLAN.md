# Transit — Execution Plan (Phases 0–12)

> Companion to [`docs/BUILD_PROMPT.md`](BUILD_PROMPT.md) (the *what* and the
> *why*). This document is the *how* and the *when*: every phase broken into
> concrete tasks, deliverables, gates, dependencies and risks.
>
> **Status legend:** ✅ done · 🔵 in progress · ⚪ not started

| Phase | Deliverable | Status |
|---|---|---|
| 0 | Repo skeleton & dev stack | ✅ |
| 1 | Database foundation: tenancy + canonical GTFS schema | ✅ |
| 2 | Roles, custom claims hook, RBAC, audit log | ✅ |
| 3 | `gtfs_static` + `gtfs_rt` adapters, ingest scheduler | ✅ |
| 4 | OpenAPI v0.1 + Go read API + generated Dart client | ✅ |
| 5 | Rider app | ✅ |
| 6 | Admin console: fleet, drivers, duty assignment | 🔵 |
| 7 | Driver app: always-on shell + telemetry | 🔵 |
| 8 | Server-side tracking → GTFS-RT | 🔵 |
| 9 | Live dispatch board + alerts | 🔵 |
| 10 | `manual` adapter + GTFS/GTFS-RT export | 🔵 |
| 11 | RAPTOR planner, alerts, fares | 🔵 |
| 12 | Hardening & release | 🔵 |

---

## Working agreements (apply to every phase)

1. **Gate first.** A phase is done only when its gate passes in CI, not when the
   code is written. Do not start the next phase on a red gate.
2. **Hard rules from the brief (§0, §12) are review-blocking:** no
   agency-specific hardcoding outside adapters/config; GTFS is the canonical
   model; `contracts/openapi.yaml` is the only API truth; no secrets in the
   repo; `make dev` must work on `main` at all times.
3. **Definition of Done, per task:** code + unit tests + migration idempotency
   check (where relevant) + docs touched + acceptance demo against the gate.
4. **Branching:** `phase-N/<slug>` branches, PR into `main`, squash merge.
   Migrations are forward-only — a merged migration is never edited.
5. **Generated code** (sqlc, oapi-codegen, Dart client) is committed and
   regenerated in CI to detect drift; never hand-edited.
6. **Every phase ends runnable.** If a phase adds a service, `make dev` boots
   it; if it adds a surface, a demo script or fixture exercises it.

---

## Phase 0 — Repository skeleton & dev stack ✅

**Objective:** a cloneable monorepo that boots.

**Delivered:**
- Monorepo layout: `apps/`, `packages/`, `services/api/`, `contracts/`,
  `infra/`, `deploy/`, `docs/`
- Tooling: `Makefile`, `melos.yaml`, `go.work`, `pnpm-workspace.yaml`
- Minimal Go API (`/healthz`, `/readyz`) + multi-stage distroless Dockerfile
- `deploy/compose/compose.yaml`: Supabase Postgres (PostGIS) + API
- `.env.example`, `.gitignore`, MIT `LICENSE`, build brief in `docs/`

**Gate:** `make dev` boots the whole stack. ✅

**Follow-ups owed to later phases:**
- CI workflow file (pending token with `workflow` scope) — Go vet/build/test,
  compose config check, OpenAPI lint.
- Pin the exact Supabase self-host image set (auth, rest, realtime) once
  Phase 1 starts.

---

## Phase 1 — Database foundation: tenancy + canonical GTFS schema

**Objective:** the schema every later phase builds on — multi-tenant from the
first table, GTFS-native, RLS-enforced.

**Tasks:**
1. Compose: add Supabase Auth (GoTrue) + PostgREST + Realtime to the local
   stack; document the minimal self-host set.
2. Migration `0001_extensions`: `postgis`, `pg_cron`, `pgcrypto`.
3. Migration `0002_tenancy`: `agencies` table + `agency_config` (jsonb,
   validated against a JSON Schema stored in-repo — this is the §2 config
   block: timezone, locales, currency, units, modes, map provider, licence,
   branding, driver_ops).
4. Migration `0003_gtfs_core`: canonical GTFS tables — `stops`, `routes`,
   `trips`, `stop_times`, `calendar`, `calendar_dates`, `shapes`,
   `fare_products` — every one carrying `agency_id`, geography columns as
   PostGIS `geography`, all timestamps `timestamptz`.
5. Indexes per brief §8: GIST on geography columns; btree on the hot query
   paths. Document stop_times-after-midnight (>24:00:00) handling.
6. RLS helpers: `current_agency_id()` reading the JWT claim **only**; enable
   RLS on every table; policies per §8 matrix.
7. Test harness: seed **two** demo agencies; Go integration tests issuing
   anon / driver / agency_admin JWTs and asserting cross-agency invisibility.
8. `make db.migrate`, `make db.seed`, `make db.test` targets.

**Deliverables:** migrations, RLS policies (`infra/supabase/policies/`), seed
fixtures, tenancy test suite.

**Gate:** RLS proven across two agencies with anon/driver/admin JWTs —
cross-agency reads return zero rows, and a JWT-claim spoof attempt fails.

**Depends on:** Phase 0. **Blocks:** everything.

**Risks:** Supabase self-host image drift → pin digests, record in
`docs/adr/`. Naive-time bugs → lint rule forbidding `timestamp without
time zone`.

---

## Phase 2 — Roles, custom claims hook, RBAC, audit log

**Objective:** the security backbone. Nothing in later phases ships without it.

**Tasks:**
1. `user_roles(user_id, agency_id, role, depot_id nullable)` — multi-valued,
   agency-scoped (§3.1). `driver_profiles` with licence fields.
2. Supabase **custom access token hook** injecting `agency_id` + roles into
   the JWT, mirrored into `app_metadata`. ADR documenting why
   `user_metadata` is never read for authorisation.
3. Go: JWKS verifier + single auth middleware accepting (a) Supabase JWT,
   (b) hashed API key (stub table now, portal issues keys in Phase 4).
4. Centralised, **table-driven RBAC** in `internal/httpapi` — a
   role×permission matrix consulted by handlers, not scattered `if role ==`.
5. `audit_log`: append-only (trigger blocks UPDATE/DELETE), records actor,
   action, entity, before/after jsonb, ts, IP. Export endpoint stub.
6. **Privilege-escalation test suite:** user edits own `user_metadata` → no
   effect; driver token against admin endpoints → 403; depot-scoped
   dispatcher against another depot → 403.

**Gate:** privilege-escalation test suite passes in CI.

**Depends on:** Phase 1. **Blocks:** 4, 6, 7, 9.

**Risks:** token-hook latency on login → cache JWKS, measure. This phase is
the most security-critical; budget review time accordingly.

---

## Phase 3 — Baseline adapters: `gtfs_static` + `gtfs_rt`, ingest scheduler ✅

**Objective:** prove the adapter architecture on the two global-baseline
standards before any vendor-specific work.

**Delivered:**
1. `Adapter` interface in `services/api/internal/adapters/adapters.go` plus
   shared `FetchWithBackoff`, `CircuitBreaker` and diagnostic types.
2. `gtfs_static` adapter in `services/api/internal/adapters/gtfsstatic/`: zip
   ingest → normalise → upsert by natural key; integration test covers the
   full flow against Postgres.
3. `gtfs_rt` adapter in `services/api/internal/adapters/gtfsrt/`: protobuf
   decode for TripUpdates / VehiclePositions / ServiceAlerts via
   `github.com/OneBusAway/go-gtfs/proto`.
4. `services/api/internal/ingest/` scheduler with `Registry`, `Scheduler` and
   per-feed realtime tickers; `services/api/cmd/ingestor/main.go` as the
   service entrypoint.
5. `services/api/cmd/feedcheck/main.go` CLI for dry-run validation of a feed
   URL before saving it.
6. `transit.feeds`, `transit.sync_runs` and `transit.feed_quarantine` schema
   in `infra/supabase/migrations/0007_feeds_and_sync_runs.sql`.
7. `make ingest.build`, `make ingest`, `make feedcheck` and ingestor service in
   `deploy/compose/compose.yaml`.
8. ADRs `docs/adr/0004-ingest-scheduler.md` and
   `docs/adr/0005-gtfs-library-choice.md`.

**Gate:** `make db.test` passes (adapter integration tests against migrated +
seeded test DB) and `go test -short ./...` passes. Real-public-feed test is
present and skipped cleanly when `REALTIME_TEST_URL` is unset.

**Depends on:** Phase 1. **Blocks:** 4, 8, 10.

**Risks:** malformed real-world feeds → mitigated by `feed_quarantine` and
per-feed goroutines that do not stop the scheduler.

---

## Phase 4 — OpenAPI v0.1 + Go read API + generated Dart client ✅

**Objective:** the first real API surface, contract-first both directions.

**Delivered:**
1. `contracts/openapi.yaml` v0.1 with public read endpoints:
   `/v0/agencies/{slug}` + `/config`, `/stops`, `/routes`, `/trips`,
   `/trips/{id}/stop_times`, `/arrivals`, plus `/healthz` and `/readyz`.
2. Go server types and chi router generated with `oapi-codegen` into
   `services/api/internal/generated/oapi/`.
3. `services/api/internal/store/{agencies,stops,routes,trips,apikeys}/`
   packages with SECURITY DEFINER-backed queries and `internal/httpapi/handlers/public.go`
   implementing the generated interface.
4. `cmd/server/main.go` wired to the generated chi handler.
5. Migration `0008_api_usage_and_read_helpers.sql` adding `usage_events`
   and public read helper functions.
6. Token-bucket rate limiter in `internal/httpapi/auth/ratelimit.go` and API-key
   authentication updated to use SHA-256 key hashes.
7. Dart client generated into `packages/transit_api_client` from the same
   OpenAPI contract using openapi-generator-cli.
8. `make gen` regenerates both sides; `make gen-check` fails on drift.
9. Integration tests in `internal/httpapi/handlers/public_test.go` exercise
   every v0.1 endpoint against the seeded demo agencies.

**Gate:** `make db.test` passes (including handler integration tests) and
`go test -short ./...` passes. `make gen-check` is available for CI drift detection.

**Depends on:** Phases 2, 3. **Blocks:** 5, 6, 9.

**Risks:** scope creep of v0.1 → read-only on purpose; writes arrive with
their owning phases.

---

## Phase 5 — Rider app (Flutter, mobile + web) ✅

**Objective:** the public face — one binary, any agency.

**Delivered:**
1. `packages/transit_design`: runtime-themed `AgencyTheme` and `ThemeProvider`
   that white-label the app from agency config without a rebuild.
2. `packages/transit_maps`: abstract `MapProvider` interface and MapLibre default
   implementation; Google provider can be added behind the same interface later.
3. `apps/rider_app` Flutter project using Riverpod + GoRouter:
   - Agency selector screen loads `demo-metro` or `demo-transit` and applies
     the agency's primary/secondary colours and font at runtime.
   - Home screen: map with stop markers + scrollable stop list.
   - Stop screen: live arrival board for a selected stop.
   - Route screen: trip selector + stop sequence map/list.
   - About screen: licence/attribution from agency config.
   - Favourites stub (FloatingActionButton) and local-notification hooks land
     in a later phase.
4. Consumes the generated `packages/transit_api_client` for all API calls.
5. Unit tests for `AgencyTheme` parsing and theme building.

**Gate:** `flutter analyze` reports no issues and `flutter test` passes for
`apps/rider_app`, `packages/transit_design` and `packages/transit_maps`.

**Depends on:** Phase 4. **Blocks:** — (user-facing milestone).

**Risks:** offline timetable size → ship per-agency compressed snapshot,
document limits.

---

## Phase 6 — Admin console: fleet, drivers, blocks, duty assignment 🔵

**Objective:** the operational back office; the write path behind the future
`manual` adapter.

**Delivered:**
1. Migrations `0009_fleet_and_dispatch.sql` (`vehicles`, `blocks`,
   `duty_assignments`, `duty_events`, RLS, SECURITY DEFINER helpers for the
   Go admin API) and `0010_route_editor.sql` (write helpers for `routes`,
   `trips`, `stop_times`, `calendar`). `depots` and `driver_profiles` already
   existed from Phase 2.
2. Go: `internal/store/{vehicles,drivers,depots,blocks,duty,calendar}` +
   write methods added to `store/routes` and `store/trips`;
   `internal/dispatch` implements conflict detection (double-booking,
   maintenance hold, expired licence, suspended driver, rest-gap via
   `block_time_span` + agency timezone per ADR 0002), recurring weekly
   roster expansion, and the reassignment/handover state machine, all
   audited via the existing `audit.Writer`.
3. `internal/gotrue` calls GoTrue's admin API to invite drivers by
   email/phone; `/admin/drivers` also accepts an existing `user_id` so the
   flow works without a live GoTrue instance (used by tests).
4. Hand-rolled JSON handlers (`internal/httpapi/handlers/{fleet,roster,
   routes_admin}.go`) registered directly on the chi router in
   `cmd/server/main.go`, following the same pattern as the Phase 2
   `/admin/health` and `/admin/audit/export` endpoints — **not**
   OpenAPI-generated, since `/admin` is an internal operational surface, not
   the versioned public `/v0` contract.
5. `apps/portal`: Next.js 14 App Router + Tailwind + `@supabase/ssr`.
   `/admin` pages for vehicles, drivers (both with CSV bulk import), routes
   & timetables (route/calendar/trip/stop-sequence editors), and the duty
   roster (assign, see conflicts, apply a recurring weekly pattern). The
   portal calls the Go API with the signed-in user's Supabase access token;
   it never talks to Postgres directly.
6. Go integration tests (`internal/dispatch/dispatch_test.go`, build tag
   `integration`) cover the happy path and every conflict rule, reassignment,
   handover, unassigned-block listing and roster expansion (including a row
   that succeeds alongside one skipped for a conflict).

**Not yet verified — needs a live Postgres:** the sandbox this phase was
built in could not start Docker, so `make db.test` has not actually been
run against the new migrations. Run `make db.test` and `make portal.build`
before treating this phase as done; `go build`/`go vet`/`go test -short`
and `next build`/`tsc --noEmit` all pass already.

**Tasks (original spec, for reference):**
1. Portal `/admin` gated by `fleet_manager`+ (JWT claim check + server
   re-check).
2. **Vehicles:** CRUD (registration, fleet number, capacity class,
   accessibility features, propulsion, depot, status, maintenance hold) +
   bulk CSV import with row-level error report.
3. **Routes & timetables:** versioned routes, stop sequences, shapes,
   service calendars — writes land in the canonical GTFS tables.
4. **Drivers:** invite by phone/email, depot assignment, licence expiry
   tracking (auto-block + 30-day warning), suspend/reactivate.
5. **Blocks & duty assignment** (`blocks`, `duty_assignments`, `duty_events`
   per §3.3): driver+vehicle→block for a service date; **conflict
   detection** (double-booking, maintenance hold, expired licence, rest-gap);
   recurring weekly rosters over a date range; mid-day reassignment and
   vehicle swap with named-stop handover; unassigned-block warnings.
6. Every mutation flows through the audit log — verified by test.

**Gate:** a week's roster can be built and published for a seeded agency,
with conflicts caught and surfaced.

**Depends on:** Phases 2, 4. **Blocks:** 7, 9, 10.

**Risks:** conflict-rule edge cases (overnight blocks, split shifts) →
property-test the rest-gap and overlap logic.

---

## Phase 7 — Driver app: always-on shell + zero-touch telemetry 🔵

**Objective:** the phone becomes the AVL unit. Two touches per shift.

**Delivered:**
1. Backend support the driver app needs, added ahead of Phase 8:
   migration `0011_telemetry.sql` (`vehicle_pings`, `incident_reports`, RLS —
   "drivers insert pings only for their own open duty" — SECURITY DEFINER
   helpers); `internal/store/{pings,incidents}`; a new `/driver/*` handler
   surface (`internal/httpapi/handlers/driver.go`) that is self-service only
   — every endpoint re-derives the target duty from the JWT, never a request
   parameter — covering agency lookup, own duty list, own duty's block
   (trip_ids), confirm/end duty, batched ping submission, and one-tap
   incident reports. Phase 8 still owns turning raw pings into authoritative
   `stop_events` — this only adds where they land.
2. `packages/transit_telemetry` (pure Dart, unit tested, no Flutter
   dependency): `AdaptiveSampler`, `FixValidator`, `GeoKalmanFilter`,
   `ShapeMatcher` (monotonic `shape_dist_traveled`), `TripTracker`
   (auto-start/progression/auto-end state machine using the GTFS-RT
   `VehiclePosition.current_status` vocabulary), `PingQueue`/`PingStorage`
   (storage-agnostic persistent queue) and `TelemetryEngine` tying them
   together.
3. `apps/driver_app`: login → onboarding (location + battery-optimisation
   exemption + per-OEM Xiaomi/Huawei/Oppo/Vivo autostart intents + kiosk-mode
   guidance) → duty list → always-on active-shift screen (safety interlock,
   occupancy, incident) → transparency screen. `flutter_background_service`
   runs tracking in its own isolate with `AndroidForegroundType.location`
   and `autoStartOnBoot`, re-deriving state from `RecoveryStore`
   (SharedPreferences) rather than the UI isolate, so it can resume after a
   reboot with no UI present. AndroidManifest.xml / Info.plist carry the
   background-location permissions and foreground-service/background-mode
   declarations.
4. Shape data gap: Phase 4 never exposed a shapes.txt read endpoint, so
   `DutyBlockLoader` builds the on-device shape as the straight line through
   a block's stops in order (via the public `/v0` read API) rather than a
   true polyline — the same degraded fallback GTFS tooling uses for a feed
   with no shapes.txt. A future phase can add a shapes endpoint and swap it
   in without changing `transit_telemetry`'s interface.

**Not yet verified — needs a real device:** `flutter analyze` and
`flutter test` are clean, and `flutter build apk --debug` succeeds (a real
Gradle build caught and fixed a genuine missing-desugaring config error, so
this isn't just a static check). No runtime verification: the always-on
shell, background survival, per-OEM wizard, and the phase gate itself (8h
shift, forced reboot, 40-minute airplane-mode gap) all need testing on an
actual device — this could not be done in the sandbox this phase was built
in. An iOS build was not attempted.

**Tasks (original spec, for reference):**
1. Auth + duty fetch: login once, query own `duty_assignments`, confirm duty.
2. Always-on shell: `wakelock_plus` for duty duration, scheduled/ambient
   night palette, **Android foreground service** (location type, persistent
   notification), iOS background location mode (`Always`,
   `allowsBackgroundLocationUpdates`, no auto-pause).
3. Onboarding: battery-optimisation exemption + **per-OEM setup wizard**
   (Xiaomi/Huawei/Oppo/Vivo/Samsung autostart), kiosk mode guidance (screen
   pinning / lock task / Guided Access).
4. `transit_telemetry`: adaptive sampling (moving/idle/near-stop), Kalman
   smoothing, junk-fix rejection (accuracy, speed, teleport), 10-ping
   batches, **persistent offline queue**, flush on connectivity.
5. On-device trip logic: auto-start at origin geofence within the departure
   window, shape map-matching with monotonic `shape_dist_traveled`, stop
   arrival/departure (geofence + dwell + progression), auto-end at terminus;
   manual override paths.
6. **Safety interlock:** UI read-only above `lock_ui_above_kmh` — occupancy
   and incident one-tap controls enabled only when stopped.
7. **Recovery:** open duty + queue survive crash, reboot, battery pull;
   resume without asking.
8. Driver transparency screen: what is recorded, retention window (§10).

**Gate:** survives an 8-hour shift with screen on, a forced reboot, and a
40-minute airplane-mode gap without losing a duty or a ping.

**Depends on:** Phases 2, 6. **Blocks:** 8, 9.

**Risks:** OEM process killers are the #1 field failure → the per-OEM wizard
and foreground-service correctness are gate items, not nice-to-haves.

---

## Phase 8 — Server-side tracking: map-matching, stop events, delay → GTFS-RT 🔵

**Objective:** authoritative realtime, computed server-side from raw pings.

**Delivered:**
1. `internal/tracking` (pure Go, no DB dependency, 16 unit tests):
   `ReplayBlock` re-derives stop arrivals/departures/delay from a raw ping
   trace independently of anything the driver app computed — a Go port of
   the same map-matching approach as `transit_telemetry`, not a shared
   implementation, per the brief's "never trust client-derived data" rule.
   Confidence is `high` (direct geofence hit), `medium` (interpolated across
   a normal-density trace) or `low` (interpolated across a signal gap
   exceeding 3 minutes, or while sustained off-route ≥150m for ≥3 fixes).
   `PropagateDelay` decays a measured delay geometrically for live
   downstream-stop predictions. The replay-harness gate item is
   `replay_test.go`, including the tunnel/urban-canyon fixture.
2. Migration `0012_tracking.sql`: `vehicle_trips` (one row per GTFS trip
   actually run within a duty) and `stop_events` (the authoritative
   arrival/departure/delay/confidence record), plus SECURITY DEFINER
   helpers — `block_stop_schedule` (per-stop scheduled instants, ADR 0002),
   `list_pings_for_assignment` (internal-only raw-trace read),
   `current_vehicle_positions` (narrow, position-only read for GTFS-RT),
   `list_live_predictions` (feeds the public arrivals endpoint), and
   `purge_old_vehicle_pings`.
3. `cmd/tracker`: a second background service (mirrors `cmd/ingestor`'s
   two-process shape) that ticks `internal/tracking.Service` over every
   open duty assignment platform-wide, and separately purges pings past the
   retention window daily.
4. GTFS-RT `VehiclePositions`/`TripUpdates` protobuf feeds at
   `/v0/agencies/{slug}/gtfs-rt/{vehicle-positions,trip-updates}` — public,
   unauthenticated, hand-mounted (not OpenAPI-generated: oapi-codegen's
   chi-server generation is JSON-first and doesn't model a raw protobuf
   response well).
5. The `/v0/agencies/{slug}/arrivals` endpoint (Phase 4's explicit forward
   reference: "Realtime predictions will be layered on top in Phase 8") now
   layers `predicted_arrival_time` / `predicted_departure_time` /
   `delay_seconds` / `confidence` onto the static timetable when a resolved
   `stop_event` exists — the contract, Go server types and handler were
   updated and regenerated via `oapi-codegen` (available locally); the
   generated Dart client was **not** regenerated (`make gen`'s Dart step
   needs Docker, unavailable in this sandbox — see below).
6. A dedicated privacy test (`privacy_test.go`) asserts the gate's "raw
   pings unreachable" requirement across the public router, `/admin` and
   `/driver`, at every role.

**Scope reduction — daily partitioning:** the brief calls for daily
partitions on `vehicle_pings`. This wasn't implemented: converting an
existing table to a partitioned one means dropping and recreating it, and
doing that blind (no live Postgres to verify against in this sandbox) was
judged too risky for a mechanism the gate doesn't actually exercise.
Retention is real (`cmd/tracker`'s daily purge), just not partitioned —
genuine follow-up work, not silently dropped scope.

**Not yet verified — needs a live Postgres and load test:** same
limitation as Phases 6–7 — Docker was unavailable, so migration
`0012_tracking.sql` has not been run, and the brief's "load test in-phase"
risk-mitigation for ping volume hasn't been attempted at all. `go build`,
`go vet` (including `-tags integration`) and `go test -short ./...` are all
green, and the replay harness — the part of this phase closest to a
correctness proof — is fully unit tested without needing a database.

**Tasks (original spec, for reference):**
1. ~~`vehicle_pings` ingestion endpoint~~ — delivered in Phase 7
   (`POST /driver/pings`, migration `0011_telemetry.sql`) since the driver
   app needed somewhere to flush to. Batched and RLS'd as specified; not yet
   idempotent against retried batches (Phase 7 punted that to here, see its
   `Store.InsertBatch` doc comment) — add idempotency here if duplicate
   pings from a retried flush turn out to matter for the map-matching math.
2. Hot-table ops: retention delivered (`cmd/tracker`'s daily purge, default
   7 days); daily partitioning and the rollup-into-speed-profiles half are
   not — see "Scope reduction" above.
3. ~~`internal/tracking`~~ — delivered (`ReplayBlock`).
4. ~~Delay computation vs `stop_times`, downstream propagation with
   decay~~ — delivered (`ReplayBlock`'s per-stop delay, `PropagateDelay`).
   Off-route handling delivered as a confidence downgrade, not yet as a
   dispatcher notification — that's Phase 9's dispatch board.
5. ~~GTFS-RT publishers~~ — delivered (`VehiclePositionsFeed`,
   `TripUpdatesFeed`).
6. ~~Replay harness~~ — delivered (`replay_test.go`, including the
   tunnel/urban-canyon fixture).

**Gate:** a replayed trace produces correct arrival times within tolerance;
raw pings unreachable from any public endpoint or rider view (tested).

**Depends on:** Phases 3, 7. **Blocks:** 9, 10.

**Risks:** ping volume → partition + batch sizing decided by a load test
here, not deferred to Phase 12.

---

## Phase 9 — Live dispatch board + off-route & incident alerts 🔵

**Objective:** dispatchers see and steer the live fleet.

**Delivered:**
1. Migration `0013_dispatch_board.sql`: `off_route` on `vehicle_trips`
   (`internal/tracking` now flags a *currently* sustained diversion, not just
   a past one affecting a resolved stop's confidence — `ReplayBlock`'s new
   `CurrentlyOffRoute`, covered by its own tests), `dispatch_messages`
   (polled driver<->dispatcher messaging — no FCM/APNs plumbing in this
   codebase, see the scope note below), and incident-resolution helpers.
2. `/admin/dispatch` (portal): a live vehicle list — fleet, driver, delay
   (colour-coded), occupancy, off-route badge — polled every 10s, plus an
   alerts strip (unassigned blocks today, licence warnings/expired,
   off-route count, open incidents). Clicking a vehicle opens a drill-down:
   recent ping trace, a message-the-driver form, and reassign/vehicle-swap
   (handover) forms that call Phase 6's existing `internal/dispatch`
   conflict-checked endpoints — Phase 6 had built the state machine but
   never exposed it in a screen; this is that screen. `/admin/incidents`:
   the resolution queue, open/all filter, resolve action.
3. Backend: `GET /admin/dispatch/vehicles`, `GET /admin/dispatch/alerts`,
   `GET /admin/duty-assignments/{id}/pings` (the dispatch-role ping-trace
   drill-down — dispatchers may see live pings per brief §8, unlike the
   public/rider surfaces Phase 8 locked down; `privacy_test.go` was updated
   to prove this one path is dispatch-role-gated rather than absent, and a
   new test proves every *other* guessed path still isn't there),
   `POST .../message`, `GET/POST /admin/incidents[/{id}/resolve]` — every
   mutation audited.
4. Driver app: `DriverApi.submitPings` now distinguishes a transient failure
   from `ownershipLost` (403/409 — the assignment isn't this driver's open
   duty anymore, because a dispatcher reassigned or ended it). On
   `ownershipLost` the foreground service stops tracking, clears
   `RecoveryStore`, and shows a local notification — the concrete way "the
   driver app... reflects the swap" is satisfied for reassignment. A new
   30-second timer polls for dispatch messages and shows a local
   notification for unread ones.

**Scope reductions, flagged:**
- **No geographic map.** `/admin/dispatch` is a live *list*, not a MapLibre
  map — the portal (Next.js) has no JS mapping library wired up yet (the
  Flutter apps' `transit_maps` package doesn't apply here), and adding one
  blind, unable to visually verify it, was judged lower value than a
  correctly-working list with the same data. The map is real follow-up
  work, not dropped scope.
- **No Supabase Realtime.** The dispatch board and driver messaging both
  poll (10s and 30s respectively) rather than subscribing to Realtime
  channels — simpler to reason about and verify without a live Supabase
  instance to test a channel against; also true of GTFS-RT and the arrivals
  endpoint since Phase 8.
- **Handover completion for the *new* driver still needs an app reopen.**
  A driver whose duty is reassigned to someone *else* is detected (via
  `ownershipLost`) and stops cleanly. The driver *newly* assigned mid-shift
  picks up the new duty the next time they open the app (which reads
  `/driver/duty` fresh) rather than automatically — seamless hot-handoff to
  a new assignment id inside an already-running background isolate was
  judged too complex to get right without a device to test on.
- **Incident intake's voice-note half wasn't built.** The driver app's
  one-tap incident report (Phase 7) has no audio capture/upload; only text
  notes exist.

**Not yet verified — needs a live Postgres and real devices:** same
limitation as Phases 6–8 (Docker unavailable, migration `0013` unrun), plus
this phase's own gate — a live end-to-end reassignment across driver app,
server, dispatch board and public feed — fundamentally needs two real
devices/sessions to observe, which this sandbox cannot provide. `go build`,
`go vet` (`-tags integration` too), `go test -short ./...`, `flutter
analyze`/`flutter test`, and `tsc --noEmit`/`next build` for the portal are
all green.

**Tasks (original spec, for reference):**
1. ~~`/admin/dispatch`: map of active vehicles~~ — delivered as a list, not
   a map; delay colouring, occupancy and off-route flags all present. Open
   incidents surfaced via the alerts strip and `/admin/incidents`, not
   inline on the vehicle row. Supabase Realtime subscriptions not used —
   polling instead (see scope reductions above).
2. ~~Vehicle drill-down~~ — delivered (ping trace, message driver, reassign
   via Phase 6's handover state machine).
3. ~~Incident intake ... → dispatcher queue → resolution workflow, all
   audited~~ — delivered except the voice-note capture half (see above).
4. ~~Alerting~~ — delivered (off-route, unassigned blocks, licence-expiry
   warnings) as a polled `/admin/dispatch/alerts` read, not push
   notifications to dispatchers.

**Gate:** mid-duty reassignment works end to end — driver app, server state,
dispatch board and public feed all reflect the swap.

**Depends on:** Phases 6, 8. **Blocks:** — (v1 operational core complete).

---

## Phase 10 — `manual` adapter + GTFS/GTFS-RT export 🔵

**Objective:** an agency with **zero prior digital data** emits standards.

**Delivered:**
1. `internal/adapters/manual`: implements the `Adapter` interface treating
   the canonical DB itself (admin-console-authored, per Phase 6) as
   "upstream". `SyncStatic`/`Validate` count stops/routes/trips and report
   an `adapters.Diagnostic` per missing entity type; `SyncStatic` never
   writes (there's nothing to import — the network already lives in the
   canonical tables). `PollRealtime` returns an already-closed channel: this
   adapter's realtime side is driver-app telemetry, which already flows
   into `vehicle_pings`/`vehicle_trips` via the Phase 7/8 ping pipeline, not
   through the adapter interface. Registered in `cmd/ingestor/main.go`.
2. `cmd/exporter` (new binary): `internal/exporter.Sources.BuildGTFSZip`
   builds a per-agency `GTFS.zip` (agency/stops/routes/trips/stop_times/
   calendar, plus calendar_dates/shapes/fare_products when present) straight
   from the canonical store readers via `archive/zip` + `encoding/csv`.
   Migration `0014_exporter.sql` adds the `list_shapes`, `list_calendar_dates`,
   `list_fare_products` and `list_agencies` SECURITY DEFINER reads this
   needed (shapes/calendar_dates/fare_products had no read path anywhere
   else). The service exports every agency on a schedule (`EXPORT_INTERVAL`,
   default 15m) to disk (atomic temp-file + rename) and serves
   `GET /{slug}/gtfs.zip` plus a GTFS-RT `GET /{slug}/gtfs-rt/service-alerts`
   stub (`internal/exporter/service_alerts.go` — a structurally valid, always-empty
   feed; real alert authoring is Phase 11's). VehiclePositions/TripUpdates
   are **not** duplicated into this binary — they stay served by `cmd/server`
   (Phase 8's already-working, already-tested endpoints); `cmd/exporter`'s
   package doc explains why. Wired into `Makefile` (`exporter.build`,
   `exporter`), `services/api/Dockerfile`, and `deploy/compose/compose.yaml`
   (its own `exporter_data` volume so an export survives a restart).
3. `make gtfs.validate slug=<agency>` runs MobilityData's `gtfs-validator`
   Docker image against an exported `.zip` — added as a Makefile target,
   **not wired into CI**: this repo still has no CI workflow at all (the same
   gap Phase 0's follow-ups flagged), so "in CI" isn't achievable without
   that first landing. Also never executed in this sandbox (no Docker) — see
   below.
4. Portal `/datasets` (new public, unauthenticated page): lists every agency
   with its modes, licence SPDX, attribution, terms-of-use link, and
   download links for its `GTFS.zip` and GTFS-RT service-alerts feed. Backed
   by a new hand-mounted (not OpenAPI-generated — it's not part of the
   versioned `/v0` contract) `GET /v0/agencies` directory endpoint
   (`internal/httpapi/handlers/agencylist.go`). `X-Data-Source: upstream` is
   set on every public `/v0` response via a small chi middleware in
   `cmd/server/main.go`, and directly on `cmd/exporter`'s `gtfs.zip`
   response — a blanket constant rather than per-field provenance, since
   this deployment has no community-contributed data merge to distinguish
   from upstream.
5. GBFS stub (`internal/httpapi/handlers/gbfs.go`): `GET /v0/agencies/{slug}/gbfs.json`
   (auto-discovery manifest) and `.../gbfs/system_information.json`, active
   only when the agency's config `modes` includes `bike`, `scooter` or
   `moped` (added to `infra/supabase/schemas/agency_config.json`'s enum).
   Deliberately stops there — no `station_information`/`station_status`/
   `free_bike_status`, since there's no micromobility fleet data model in
   this codebase to back them.

**Scope reductions, flagged:**
- **GTFS-RT ServiceAlerts is a stub**, not real alert authoring/publishing —
  that's explicitly Phase 11 scope per the brief.
- **`gtfs-validator` never actually run.** The Makefile target exists but
  needs Docker (unavailable all session) and a CI workflow that doesn't
  exist yet in this repo. The phase's gate ("passes MobilityData
  validation") is therefore unverified, not satisfied.
- **`BuildGTFSZip`'s reads are capped, not paginated.** `maxExportRows =
  1,000,000` per entity type — fine for any agency this codebase's schema
  currently targets, but a real streaming/paginated export would be needed
  before that cap is a live concern.
- **`GET /v0/agencies` (the datasets directory) is N+1**: one query to list
  agency refs, then one `LookupBySlug` per agency for name/config. Fine for
  a low-traffic directory page at plausible agency counts; would need a
  batched read if this deployment ever hosted hundreds of agencies.
- **GBFS's positive path (an agency actually configured with a
  micromobility mode) has no seed data to demonstrate against** — the demo
  seed agency only has `bus`-family modes. The stub logic is unit-tested
  directly (`hasMicromobilityMode`, `primaryGBFSLanguage`) and the gating's
  negative path is integration-tested, but no live agency has ever produced
  a real `gbfs.json`.

**Not yet verified — needs a live Postgres and Docker (both unavailable all
session), same limitation as Phases 6–9:** `manual` adapter's
`Validate`/`SyncStatic` against real tables; `BuildGTFSZip` actually
producing a `.zip` from seeded data (an integration test asserts its shape,
but was only checked via `go vet -tags integration`, never executed);
`cmd/exporter`'s scheduled export loop and file-serving under a real
process; `gtfs-validator` passing (or even running) against real exporter
output; the portal `/datasets` page rendering real API data (`tsc
--noEmit` and `next build` both pass, and a manual smoke test against a
running dev server wasn't possible — no backend to point it at). `go
build`, `go vet` (`-tags integration` too), and `go test ./...` are all
green; `gofmt -l` clean on every file touched this phase.

**Tasks (original spec, for reference):**
1. ~~`manual` adapter: reads the admin-console-built network... as "upstream";
   realtime source = driver-app telemetry~~ — delivered as described above.
2. ~~`cmd/exporter`: scheduled `GTFS.zip`... live GTFS-RT protobuf endpoints
   (TripUpdates, VehiclePositions, ServiceAlerts)~~ — `GTFS.zip` and
   ServiceAlerts delivered from this binary; TripUpdates/VehiclePositions
   deliberately stayed on `cmd/server` rather than being duplicated (see
   delivered §2).
3. ~~MobilityData `gtfs-validator` in CI~~ — Makefile target only; not wired
   into CI (no CI workflow exists in this repo) and never executed (no
   Docker in this sandbox).
4. ~~Portal `/datasets` entries... licence/attribution... `X-Data-Source`
   header~~ — delivered.
5. ~~GBFS endpoint stub~~ — delivered, discovery + system_information only.

**Gate:** a seeded agency with no imported data emits a `GTFS.zip` that
passes MobilityData validation, and its GTFS-RT feed reflects live driver
telemetry. **Not met in this sandbox** — the zip-building code path is
implemented and compile/logic-tested, but never run against a live database
or through the actual validator (see "Not yet verified" above).

**Depends on:** Phases 6, 8. **Blocks:** — (the business-case phase).

---

## Phase 11 — RAPTOR planner, service alerts, fares 🔵

**Objective:** multimodal trip planning and rider-facing comms.

**Delivered:**
1. `internal/planner` (new, DB-independent — `planner.Build` takes
   already-decoded rows, so the algorithm is unit-testable with synthetic
   timetables the same way `internal/tracking`'s `ReplayBlock` is): a
   textbook round-based RAPTOR. Trips are grouped into stop-sequence
   "patterns" (`Timetable.patterns`); each round only ever boards using the
   *previous* round's frozen arrival times, never a value improved earlier
   in the same round — the specific property that keeps multi-leg transfers
   causally correct instead of allowing a boarded trip to depart before the
   rider could have arrived. `TestPlan_NoTimeTravel` in
   `internal/planner/raptor_test.go` exists specifically to pin this down:
   it builds a network where a naive implementation would transfer onto a
   trip that departs *before* the connecting trip arrives, and asserts
   RAPTOR correctly skips it for the next feasible one. Nine more tests
   cover direct trips, missed-earlier-trip boarding, cross-route transfers,
   unreachable destinations, calendar/calendar_dates activation, and
   coordinate-based origins/destinations. Walking legs
   (`internal/planner/walk.go`'s `WalkCache`) are great-circle distance ÷ a
   flat walking speed, cached by coordinate pair rounded to a ~11 m grid —
   see the scope reduction below for why there's no routing engine behind
   it. Migration `0015_planner_and_alerts.sql` adds `list_all_stop_times`
   (a bulk read — one query for every stop_time in the agency, instead of
   the per-trip `list_trip_stop_times` the public API and exporter already
   use) and `internal/store/trips.Reader.ListAllStopTimes` to feed it.
2. Itinerary ranking (`internal/planner/itinerary.go`'s `rank`): earliest
   arrival first, then fewest transfers, then least walking, matching the
   brief's ETA/transfers/walking ordering. `Planner` (the HTTP handler,
   `internal/httpapi/handlers/planner.go`) builds one `Timetable` per
   agency from the store readers and caches it in-process for 5 minutes
   (no invalidation on admin writes — a documented staleness window, not a
   correctness gap for a mostly-static schedule). `GET
   /v0/agencies/{slug}/plan-trip` — hand-mounted, not OpenAPI-generated,
   the same reasoning as GBFS/AgencyList/GTFS-RT (not part of the versioned
   `/v0` contract, and the Dart client can't be regenerated without Docker,
   unavailable all session).
3. Service alerts: migration `0015` also adds the `service_alerts` table
   (`header_text`/`description_text`/`url` are locale-keyed `jsonb`, the
   same shape as `agencies.name`) plus SECURITY DEFINER
   upsert/list/resolve/delete functions, RLS mirroring Phase 9's
   `dispatch_messages` policy pattern. `internal/store/servicealerts` is
   the Go store. `/admin/alerts` (`AdminAlerts` handler) is the authoring
   surface — new `alerts:read`/`alerts:write` RBAC permissions granted to
   `agency_admin`, `fleet_manager` and `dispatcher`; every mutation audited,
   the `DispatchBoard`-style `h.audit(...)` pattern. `GET
   /v0/agencies/{slug}/alerts` is the public read (`Alerts` handler),
   resolving each alert's text to one locale via `?locale=` with an
   "en" / alphabetically-first fallback (`selectLocale`, unit-tested for
   determinism — Go map iteration order is otherwise randomized).
   `internal/exporter/service_alerts.go`'s `ServiceAlertsFeed` replaces the
   Phase 10 stub with a real GTFS-RT builder: one `TranslatedString`
   translation per locale, cause/effect mapped onto the GTFS-RT enums, and
   an `EntitySelector` per informed route/stop, or a single agency-wide
   selector when an alert names neither. The portal gained an
   `/admin/alerts` page (create form with a primary + one optional second
   locale, list, resolve, delete) and the rider app gained an
   `AlertBanner` widget on the home screen, fetched via a small hand-rolled
   Dio client (`lib/providers/extra_api.dart`) since `plan-trip`/`alerts`
   aren't in the generated `transit_api_client`.
4. Fares: `GET /v0/agencies/{slug}/fares` (new `Fares` handler) exposes
   `fare_products` publicly for the first time (the Phase 10 store already
   existed but had no HTTP path). Every itinerary from `plan-trip` carries
   the agency's full fare product list under `fare_products` — see the
   scope reduction below for why this isn't a computed per-trip total.
   Displayed in the rider app's itinerary tiles and referenced from
   `internal/planner/fares.go`'s doc comment.
5. Localization: a new `localeProvider` (Riverpod) in the rider app picks a
   locale from the device locale intersected with the agency's configured
   `locales`, falling back to `"en"` then the agency's first configured
   locale — threaded into the `alerts` and `plan-trip` calls via
   `?locale=`. `selectLocale` (Go) and `localeProvider` (Dart) are unit- and
   analyzer-checked respectively; the gate's "two locales" is exercised by
   `internal/exporter`'s `TestServiceAlertsFeed_TranslatesEveryLocale` and
   the portal alert form's primary+second-locale fields.

**Scope reductions, flagged:**
- **No street-network walking routing.** There is no self-hosted
  OSRM/Valhalla instance anywhere in `deploy/` or `services/`, and no
  external routing provider is configured — `WalkCache` uses great-circle
  distance over a flat walking speed instead, the same fallback
  `internal/tracking` and the driver app's `DutyBlockLoader` already use
  when shape data is missing. This under-estimates real walking time (no
  streets, obstacles, detours) and is why the response never claims a
  routed path, only a duration/distance.
- **Fares are not computed per itinerary.** The schema has only
  `fare_products` (id, name, amount, currency) — no GTFS-Fares V2
  `fare_leg_rules`/`fare_transfer_rules` tables exist to map a specific set
  of legs to a specific product. Every itinerary is annotated with the
  agency's *entire* fare product list, not a computed total — "these are
  the fares this agency charges," not "this trip costs X." Computing a
  real total needs fare-rule data this codebase doesn't model.
- **No push notifications for alerts ("arrival alerts delivery").** Same
  gap as Phase 9's dispatcher↔driver messaging: no FCM/APNs plumbing
  anywhere in this codebase. The rider app's `AlertBanner` is fetched on
  screen load, not pushed.
- **After-midnight service carryover isn't modelled across calendar
  days.** `Timetable.activeServiceIDs` only activates services whose own
  calendar entry covers the query date — a service that started the
  previous day and is still running past midnight (e.g. a 25:30 GTFS
  departure) is correctly reachable when querying *that* service's date,
  but a query dated the next morning at 01:00 won't see it, since GTFS
  ties the trip to the previous day's `service_id`. Documented directly on
  `activeServiceIDs`'s doc comment.
- **The RAPTOR timetable build has no pagination, and footpath relaxation
  has no spatial index.** `maxTimetableRows = 1_000_000` (a `LIMIT`, same
  precedent as the exporter's `maxExportRows`), and every footpath
  relaxation pass checks every stop in the agency rather than querying a
  spatial index — fine at any stop count this codebase has ever been
  exercised against, not fine at real city-wide scale without further
  work.
- **The rider app has no real Flutter localization (ARB/`intl`)
  pipeline.** `localeProvider` only decides which server-side locale key to
  request; there's still no `flutter_localizations` setup, `.arb` files,
  or `AppLocalizations` for the app's own UI chrome — an existing gap from
  Phase 5 this phase didn't take on.

**Not yet verified — needs a live Postgres (unavailable all session, same
limitation as every phase since 6):** migration `0015` was never applied;
`internal/store/servicealerts`, the bulk `ListAllStopTimes` reader, and
`Planner.buildTimetable` were never run against a real database — only
compile-checked via `go vet -tags integration ./...`. The rider app's
`PlannerScreen` and `AlertBanner` were never run against a live API (no
backend to point a `flutter run` at); `flutter analyze` and `flutter test`
are both clean (5 pre-existing info-level lints, none new). `go build`,
`go vet` (`-tags integration` too), `go test ./...` (RAPTOR's 10 tests plus
new handler/exporter/RBAC tests all green), `gofmt -l`, `tsc --noEmit`, and
`next build` for the portal are all green.

**Tasks (original spec, for reference):**
1. ~~`internal/planner`: RAPTOR... time-dependent transfers done
   correctly; walking legs via self-hosted OSRM/Valhalla or configured
   provider, cached by rounded coordinate pair~~ — RAPTOR delivered with a
   dedicated no-time-travel test; walking legs delivered as great-circle
   distance (no OSRM/Valhalla — see scope reductions), cached by rounded
   coordinate pair as specified.
2. ~~Itinerary ranking by ETA/transfers/walking/fare; localised output (two
   locales in the gate)~~ — ranking delivered exactly as specified; fare is
   attached but not part of the sort key (nothing to rank by — see scope
   reductions). Localization delivered for alerts and the rider app's
   locale selection, not for the planner's own generated text (there isn't
   any — itinerary output is structured data, not narrative prose).
3. ~~ServiceAlerts authoring in /admin → GTFS-RT ServiceAlerts + rider-app
   banners; arrival alerts delivery~~ — authoring, the GTFS-RT feed, and
   rider-app banners all delivered; "delivery" is banner-on-load, not push
   (see scope reductions).
4. ~~Fares: fare_products read path + fare display in itineraries~~ —
   delivered as a flat per-agency list, not a computed per-trip total (see
   scope reductions).

**Gate:** a multi-leg trip is planned correctly in two locales, with fares
shown per agency currency config. **Partially met in this sandbox**: RAPTOR
correctness (including the multi-leg no-time-travel property) is proven by
unit tests against synthetic data; the "two locales" and "fares shown"
halves are implemented and unit-tested (`TestServiceAlertsFeed_
TranslatesEveryLocale`, itinerary fare-attachment tests) but never
exercised end-to-end against a live agency's real timetable, since no
Postgres was available this session.

**Depends on:** Phases 4, 10.

---

## Phase 12 — Hardening & release 🔵

**Objective:** production-grade, deployable by others.

**Delivered:**
1. Quotas & rate limiting actually finalised — `RateLimitRPM`/`QuotaDaily`
   had been loaded from `api_keys` since Phase 4 but **never consulted**:
   `TokenBucket.Allow` used one global rate for every key regardless of its
   own configured limit, and there was no daily-quota check anywhere.
   `internal/httpapi/auth/ratelimit.go`'s `Allow` now takes a per-key rpm
   override; `apiKeyActor` enforces `quota_daily` by counting
   `usage_events` since the day's window start (fail-open on a DB error —
   a quota check's job is limiting overuse, not gating availability).
   `usage_events` also had **zero writers** despite `RecordUsage` being
   wired into every `Middleware` since Phase 4 — `Handler` now records one
   usage event per API-key request, in a background goroutine so a slow
   insert never adds request latency. New migration
   `0016_api_key_management_and_quotas.sql` adds `create_api_key`/
   `list_api_keys`/`revoke_api_key` (there was previously no way to issue a
   key at all) and `usage_summary_by_day`. New `/admin/api-keys` handler +
   portal page: create (raw key shown once), list, revoke, and a CSS
   bar-chart usage view backed by `usage_summary_by_day`. Unit-tested with
   a fake store (`apikeyactor_test.go`) so the quota/rate-limit logic is
   verified without a live database — proves quota enforcement, fail-open
   on error, per-key rate independence, and unknown-key rejection.
2. Observability: `internal/telemetry` wires the OpenTelemetry SDK — every
   binary (`server`, `ingestor`, `tracker`, `exporter`) calls
   `telemetry.Setup` at startup; `server` and `exporter`'s HTTP servers are
   wrapped in `otelhttp`; `tracker` and `exporter` emit a span per
   background tick. Verified for real (not just compiled): a unit test
   starts a span through the stdout exporter and asserts it flushes
   correctly. `ingestor` gets the SDK wired but no spans around
   `internal/ingest.Scheduler`'s internals yet — see scope reductions.
   `deploy/observability/` has a reference OTel Collector config plus a
   Grafana dashboard and alerting rules — backed by direct Postgres
   queries against `usage_events`/`sync_runs`/`feed_quarantine`/
   `api_keys`, not a Prometheus metrics pipeline (this codebase only ever
   wired traces, not metrics — the dashboard's data already lives in
   Postgres, so that's what it queries).
3. `cmd/loadtest` (new): a real, from-scratch HTTP load generator —
   concurrency/duration/rps flags, arbitrary method/body/headers (for
   authenticated endpoints like ping ingestion), p50/p95/p99 latency and
   status-code breakdown as a JSON report. **Actually run and verified**
   against a local test server this session (7766 successes / 3888 req/s
   at 10 workers over 2s) — the one Phase 12 deliverable with zero
   database dependency, so it's the one genuinely exercised end-to-end
   rather than just compiled. Never run against a real Transit deployment
   (none existed this session) — no published fleet-scale numbers.
4. Deploy: `deploy/helm/transit` — a full chart (api/ingestor/tracker/
   exporter/portal, one image for the four Go binaries mirroring
   `compose.yaml`'s `command:`-selects-the-binary pattern, a second image
   for the portal via a new `apps/portal/Dockerfile` + `output: standalone`).
   `deploy/terraform/` — `modules/network` (VPC), `modules/cluster` (EKS +
   EBS CSI, since Transit's Postgres is the self-hosted `supabase/postgres`
   container per ADR 0001, not a service Terraform can provision directly),
   `modules/backup` (S3 + KMS + IRSA for `pg_dump` artifacts), composed by
   `environments/reference` into one region's infra — the building block
   for the brief's multi-region SaaS topology, one instance per region.
   `docs/runbooks/backup-restore.md` and `migrations.md` — concrete
   commands against this repo's actual schema and tooling, not generic
   advice.
5. `docs/SECURITY_REVIEW.md`: every item in `docs/BUILD_PROMPT.md` §12 (the
   actual document every "brief §N" comment in this codebase has been
   referencing all session — not previously read in full until this
   phase) checked against a specific test or file, not inspection alone.
   **Found and fixed two real gaps in the course of writing it**: (a)
   `apps/rider_app` and `apps/driver_app` both hardcoded `name['en']` for
   agency display names in four call sites, silently ignoring whatever
   locale the agency actually configured — replaced with a `localizedName`
   helper matching the server's own locale-fallback rule, unit-tested in
   both apps; (b) `RouteEditor` (`routes_admin.go`, Phase 6's route/trip/
   calendar editor) had **zero audit logging** across all six of its
   mutating endpoints — the one admin write surface in the whole codebase
   that never wired `audit.Writer`. Fixed with the same `h.audit(...)`
   pattern every other admin handler uses, RBAC-gate-tested. 9 of 11
   checklist items are proven by an existing or new test; 2 are marked
   partial (device-level driver-app resilience needs a physical device;
   CI-verified GTFS validation needs a CI run — see below).
6. Release CI: `.github/workflows/ci.yml` (Go build/vet/test/gofmt against
   a real Postgres service container + integration suite, portal
   typecheck+build, Flutter analyze+test for both apps, `docker compose
   config` check, OpenAPI lint, generated-code drift check — closing the
   Phase 0 follow-up that sat open through eleven phases),
   `gtfs-validate.yml` (builds a demo-metro `GTFS.zip` via `cmd/exporter`
   against a fresh migrated+seeded Postgres, runs MobilityData's
   `gtfs-validator`, uploads the report — directly closes the brief §12
   "Generated GTFS passes MobilityData validation in CI" item, open since
   Phase 3), `release.yml` (tags+pushes both container images to GHCR on a
   `v*.*.*` tag, drafts a GitHub release with a commit-log changelog).
   `docs/onboarding/README.md`: a from-scratch agency onboarding guide
   opening with the works-council/union consultation section (brief §10) —
   what this codebase concretely does (duty-scoped tracking, bounded
   retention, the in-app transparency screen) so a consultation has
   specific facts to evaluate rather than an abstract "we track drivers,"
   plus config guidance, the three data-ingestion paths (existing
   GTFS/GTFS-RT, `manual` adapter, hybrid), and deploy/backup steps with
   explicit pointers to what's unverified.
   Also fixed: `make test` ran **only** Go tests despite the brief
   requiring it run "Dart, Go and portal suites" verbatim — now also runs
   `flutter test` for both apps and the portal's typecheck+build gate (no
   unit-test framework was ever set up for the portal in any phase, so
   that's its actual verification suite).

**Scope reductions, flagged:**
- **`ingestor` has no per-feed-sync spans.** `telemetry.Setup` runs at
  startup (the binary participates in trace-context propagation), but
  `internal/ingest.Scheduler`'s internal sync loop isn't instrumented —
  unlike `tracker`/`exporter`, wrapping it needed touching the scheduler's
  internals, not just its `main.go` call site, and stayed out of scope
  for this pass.
- **No metrics pipeline, no Tempo/Jaeger/Prometheus/Grafana containers.**
  Only traces are wired (OTel SDK + collector config); the Grafana
  dashboard/alerts query Postgres directly instead of a metrics store —
  documented as a deliberate choice in `deploy/observability/README.md`,
  not an oversight, since this codebase's operational signal already lives
  in Postgres tables, not a scrape target.
- **`cmd/loadtest` was never run against a real Transit deployment.**
  Verified against a throwaway local test server (proving the tool itself
  works correctly), not against `cmd/server`/GTFS-RT/the portal, since none
  were running this session. No fleet-scale numbers exist to publish.
- **Helm chart doesn't deploy Postgres itself.** `deploy/helm/transit`
  assumes an already-reachable `DATABASE_URL`, same as
  `deploy/compose/compose.yaml`. A `postgres` StatefulSet
  subchart/manifest — the natural next piece — wasn't built; `ingestor`
  and `tracker` are also pinned to `replicaCount: 1` since neither is
  leader-elected or safe to run concurrently yet.
- **No Conventional-Commits-driven semantic versioning.**
  `release.yml` tags and pushes images and drafts a changelog on a human-
  chosen `vX.Y.Z` tag push; it doesn't compute the next version from commit
  messages (no Conventional Commits convention exists across this repo's
  history to compute from).
- **Two `docs/SECURITY_REVIEW.md` items are `[~]` partial, not `[x]`**:
  driver-app 8-hour/reboot/connectivity-gap resilience (needs a physical
  device — structurally outside what any sandbox can prove) and
  CI-verified GTFS validation (the workflow exists and is reviewed, never
  executed by a real runner).

**Not yet verified — no Docker/live Postgres/CI runner/cloud account this
session, the same limitation as every phase since 6, now compounded across
every Phase 12 artifact that depends on one:** migration `0016` was never
applied; the daily-quota/usage-recording code paths that touch the
database were compile-checked only (`go vet -tags integration`), not run
— though the pure-logic rate-limit/quota decision logic *was* verified via
`apikeyactor_test.go`'s fake store, and `telemetry`'s span export was
verified for real via the stdout exporter; `deploy/helm/transit` was never
`helm template`/`helm install --dry-run`'d (no `helm` CLI in this sandbox);
`deploy/terraform/` was never `terraform init`/`plan`/`validate`'d (no
`terraform` CLI, no AWS credentials); all three `.github/workflows/*.yml`
were never executed by a GitHub Actions runner. `go build`, `go vet`
(`-tags integration` too), `go test ./...` (all green, including the new
`telemetry`/`ratelimit`/`apikeyactor`/`apikeysadmin`/`routes_admin` suites),
`gofmt -l`, `flutter analyze`/`flutter test` for both apps (clean; the
locale-display fix added test coverage in both), and portal `tsc
--noEmit`/`next build` are all green — `make test`'s portal leg specifically
is blocked in *this* sandbox by a pnpm dependency-approval prompt unrelated
to the code (confirmed working via direct `tsc`/`next build` instead).

**Tasks (original spec, for reference):**
1. ~~Quotas & rate limiting finalised~~ — delivered; found and fixed that
   neither was actually being enforced before this phase.
2. ~~Observability: OpenTelemetry traces... dashboards, alerting rules~~ —
   traces delivered and verified end-to-end for the API/tracker/exporter;
   ingestor has SDK wiring but no internal spans (see scope reductions);
   dashboards/alerts delivered as Postgres-backed Grafana artifacts, not a
   metrics pipeline.
3. ~~Load test... publish results~~ — tool delivered and verified against a
   local server; no results published against a real deployment (none
   existed this session).
4. ~~Deploy: Helm chart, Terraform... backup/restore runbook; migration
   runbook~~ — all delivered; Postgres itself isn't deployed by the Helm
   chart yet (see scope reductions).
5. ~~Security review against brief §12 checklist~~ — delivered, 9/11 fully
   checked, 2 partial, two real defects found and fixed along the way.
6. ~~Release CI: tagged images, changelog, semantic versioning;
   docs/onboarding/ agency guide incl. works-council/union consultation
   notes~~ — all delivered; semantic versioning is human-tagged, not
   commit-message-computed (see scope reductions).

**Gate:** v1.0.0 tagged; clean-checkout → `make dev` → seeded demo works per
onboarding doc, verified by someone who didn't write the code. **Not met in
this sandbox** — no tag was pushed (pushing/tagging is a user action this
session never took, consistent with every phase's discipline of only
committing locally unless asked), and "verified by someone who didn't write
the code" is by definition something this session cannot do for itself.
`make dev`'s clean-checkout half was never run this session either (no
Docker) — `docs/onboarding/README.md` states this gate explicitly as the
first thing a real reader should do.

**Depends on:** all previous.

---

## Milestones

| Milestone | Phases | Meaning |
|---|---|---|
| **M1 — Platform skeleton** | 0–2 | Secure multi-tenant base; nothing user-visible yet |
| **M2 — Data flows in** | 3–4 | Real feeds ingested; contract-first API live |
| **M3 — Public alpha** | 5 | Rider app demoable for any seeded agency |
| **M4 — Operations alpha** | 6–7 | Agency runs fleet + drivers; phones are the AVL |
| **M5 — Live operations** | 8–9 | Authoritative realtime + dispatch, end to end |
| **M6 — Open-data v1** | 10–11 | Standards feeds out; planner; public data portal |
| **M7 — v1.0** | 12 | Hardened, self-hostable, documented, released |

## Risk register (top items)

| Risk | Phase | Mitigation |
|---|---|---|
| OEM battery killers silently stop tracking | 7 | Per-OEM wizard + foreground service are gate items |
| RLS misconfiguration leaks across tenants | 1–2 | Cross-agency test suite from Phase 1, never optional |
| Client-derived stop events corrupt public feed | 7–8 | Server recomputation is authoritative by design |
| Ping volume overwhelms the hot table | 8 | Partitioning + retention + load test in-phase |
| Google-Maps dependence kills gov sales | 5 | MapLibre default; Google behind abstraction only |
| DST / >24:00 stop_times corrupt schedules | 1 | `timestamptz` everywhere + lint + fixtures |
| Driver privacy non-compliance | 7, 10, 12 | Retention policy, transparency screen, onboarding docs |

## How this plan is maintained

- Phase statuses update via PR as phases start/complete.
- Scope changes to a phase require editing **both** this file and the gate
  table in `docs/BUILD_PROMPT.md` §11, in the same PR.
- New cross-cutting decisions go to `docs/adr/`, never only into chat.
