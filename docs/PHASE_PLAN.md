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
| 6 | Admin console: fleet, drivers, duty assignment | ⚪ |
| 7 | Driver app: always-on shell + telemetry | ⚪ |
| 8 | Server-side tracking → GTFS-RT | ⚪ |
| 9 | Live dispatch board + alerts | ⚪ |
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

## Phase 6 — Admin console: fleet, drivers, blocks, duty assignment

**Objective:** the operational back office; the write path behind the future
`manual` adapter.

**Tasks:**
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

## Phase 7 — Driver app: always-on shell + zero-touch telemetry

**Objective:** the phone becomes the AVL unit. Two touches per shift.

**Tasks:**
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

## Phase 8 — Server-side tracking: map-matching, stop events, delay → GTFS-RT

**Objective:** authoritative realtime, computed server-side from raw pings.

**Tasks:**
1. `vehicle_pings` ingestion endpoint (batched, idempotent, RLS: driver may
   insert only for own open duty).
2. Hot-table ops: daily partitions, configurable raw retention (default 7
   days), rollup into `stop_events` + speed profiles (§8).
3. `internal/tracking`: re-run map-matching and stop detection over the raw
   trace; emit `stop_events` with `confidence` and `derived_by`; client
   results treated as hints only.
4. Delay computation vs `stop_times`, downstream propagation with decay;
   off-route handling marks predictions low-confidence.
5. GTFS-RT publishers: VehiclePositions (`current_status` /
   `current_stop_sequence` per spec enums) and TripUpdates — **the same
   numbers served to the rider app**, so surfaces never disagree.
6. Replay harness: recorded traces → expected arrival times; tunnel/urban-
   canyon fixture asserting staleness behaviour.

**Gate:** a replayed trace produces correct arrival times within tolerance;
raw pings unreachable from any public endpoint or rider view (tested).

**Depends on:** Phases 3, 7. **Blocks:** 9, 10.

**Risks:** ping volume → partition + batch sizing decided by a load test
here, not deferred to Phase 12.

---

## Phase 9 — Live dispatch board + off-route & incident alerts

**Objective:** dispatchers see and steer the live fleet.

**Tasks:**
1. `/admin/dispatch`: map of active vehicles with delay colouring, occupancy,
   off-route flags, open incidents; Supabase Realtime subscriptions scoped
   by RLS (dispatchers see only open duties in their agency/depot, §8).
2. Vehicle drill-down: ping trace view, message driver, reassign (uses
   Phase 6 handover state machine mid-duty).
3. Incident intake from the driver app (one-tap + voice note) → dispatcher
   queue → resolution workflow, all audited.
4. Alerting: off-route sustained beyond threshold, unassigned blocks at
   service-day start, licence-expiry warnings.

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
