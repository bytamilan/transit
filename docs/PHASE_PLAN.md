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
| 10 | `manual` adapter + GTFS/GTFS-RT export | ⚪ |
| 11 | RAPTOR planner, alerts, fares | ⚪ |
| 12 | Hardening & release | ⚪ |

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

## Phase 10 — `manual` adapter + GTFS/GTFS-RT export

**Objective:** an agency with **zero prior digital data** emits standards.

**Tasks:**
1. `manual` adapter: reads the admin-console-built network (Phase 6) as its
   "upstream"; realtime source = driver-app telemetry with ping-age
   confidence (§9 of brief).
2. `cmd/exporter`: scheduled `GTFS.zip` from canonical tables; live GTFS-RT
   protobuf endpoints (TripUpdates, VehiclePositions, ServiceAlerts).
3. **MobilityData `gtfs-validator` in CI** against exporter fixtures; new
   errors fail the build.
4. Portal `/datasets` entries for the emitted feeds with licence/attribution
   from agency config; `X-Data-Source` header on API responses (§10).
5. GBFS endpoint stub where micromobility modes are configured.

**Gate:** a seeded agency with no imported data emits a `GTFS.zip` that
passes MobilityData validation, and its GTFS-RT feed reflects live driver
telemetry.

**Depends on:** Phases 6, 8. **Blocks:** — (the business-case phase).

---

## Phase 11 — RAPTOR planner, service alerts, fares

**Objective:** multimodal trip planning and rider-facing comms.

**Tasks:**
1. `internal/planner`: **RAPTOR** over the in-memory timetable
   (time-dependent transfers done correctly); walking legs via self-hosted
   OSRM/Valhalla or configured provider, cached by rounded coordinate pair.
2. Itinerary ranking by ETA / transfers / walking / fare; localised output
   (two locales in the gate).
3. ServiceAlerts authoring in `/admin` → GTFS-RT ServiceAlerts + rider-app
   banners; arrival alerts delivery.
4. Fares: `fare_products` read path + fare display in itineraries.

**Gate:** a multi-leg trip is planned correctly in two locales, with fares
shown per agency currency config.

**Depends on:** Phases 4, 10.

---

## Phase 12 — Hardening & release

**Objective:** production-grade, deployable by others.

**Tasks:**
1. Quotas & rate limiting finalised (per-key token bucket, daily quotas,
   portal charts against `usage_events`).
2. Observability: OpenTelemetry traces across ingest/tracking/API,
   structured logs, upstream-latency and sync-failure dashboards, alerting
   rules.
3. Load test: pings ingestion at target fleet scale, GTFS-RT fan-out, portal
   concurrency; publish results.
4. Deploy: Helm chart (`deploy/helm/`), Terraform for the reference SaaS /
   regional topology; backup/restore runbook; migration runbook.
5. Security review against brief §12 checklist — every box proven by test or
   artifact, not inspection.
6. Release CI: tagged images, changelog, semantic versioning;
   `docs/onboarding/` agency guide incl. works-council/union consultation
   notes for driver telemetry (§10).

**Gate:** v1.0.0 tagged; clean-checkout → `make dev` → seeded demo works per
onboarding doc, verified by someone who didn't write the code.

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
| **M6 — Open-data v1** | 10–11 | Standards feeds out; planner; the DataMall equivalent |
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
