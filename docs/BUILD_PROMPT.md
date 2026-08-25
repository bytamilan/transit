# Build Prompt — Transit: A Deployable Land Transport Data Platform

> A land transport data platform any transport authority can deploy — inspired by
> Singapore's LTA DataMall, but agency-agnostic. Paste this whole file into
> Claude Code as the opening brief. Execute in phases.

---

## 0. Role & Ground Rules

You are the lead engineer scaffolding a production-grade **monorepo**. Work in
phases. After each phase, stop, summarise what was created, and wait for
approval.

Hard rules:

1. **Nothing agency-specific may be hardcoded anywhere.** No country, currency,
   language, timezone, map provider, fare rule, or upstream vendor may appear
   outside an adapter or a config file.
2. **GTFS is the canonical internal model.** Every upstream adapter normalises
   *into* GTFS + GTFS-Realtime. Every output serialises *out of* it.
3. `contracts/openapi.yaml` is the single source of truth for our REST API. Dart
   clients and Go server types are generated from it — never hand-write a model
   on one side only.
4. Do not invent upstream endpoint paths or field names from memory. Fetch the
   relevant spec and generate constants from it.
5. Every phase ends with something runnable. `make dev` must work at all times.
6. No secrets in the repo. `.env.example` only.

---

## 1. What This Is

A transport authority — national, state, or municipal — deploys Transit and gets
four things at once:

**A. Driver App (Flutter, mobile)**
A mounted, always-on, near-zero-interaction terminal. The driver logs in once at
the start of a shift, confirms their assigned duty, and the app tracks
everything else automatically from GPS. Critical for agencies whose fleets have
**no AVL hardware at all** — here the phone *is* the telemetry system. Full
behaviour in §4.

**B. Rider App (Flutter, mobile + web)**
- Map with live vehicle markers labelled by route short name, server-clustered
- Nearby stops → arrivals board (ETA, occupancy, accessibility)
- Route shape + stop sequence
- Multimodal itinerary planner ranked by ETA / transfers / walking / fare
- Favourites, arrival alerts, full offline fallback to the static timetable

**C. Data Portal + Admin Console (web)**
The DataMall equivalent plus the agency's operational back office:
- `/datasets` — every exposed dataset: schema, frequency, sample payload, licence
- `/request` — access request (organisation, use case, datasets, QPS) → review queue → issued API key
- `/docs` — rendered from OpenAPI with a try-it console
- `/dashboard` — key management, rotation, quota and usage charts
- `/admin` — fleet, routes, drivers, duty assignment, live dispatch board (§3)

**D. Standards-Compliant Output Feeds**
Publishable `GTFS.zip` and `GTFS-RT` protobuf endpoints (TripUpdates,
VehiclePositions, ServiceAlerts), plus GBFS where micromobility is configured.
This makes the agency's data consumable by Google Maps, Moovit, Citymapper and
OpenTripPlanner with zero integration work on either side — often the entire
business case.

---

## 2. Tenancy Model

Multi-tenant from day one, single-tenant as a degenerate case. Retrofitting
tenancy later means touching every query and every policy.

- `agencies` is the tenant root; every domain table carries `agency_id`
- RLS scopes on `agency_id` from the JWT claim, never from a request parameter
- Deployment modes from one image: self-hosted single agency, regional
  multi-agency (a national access point), or managed SaaS

**Assume most government buyers demand self-hosting and in-country data
residency.** Supabase self-hosts; keep every dependency self-hostable and record
any that isn't in `docs/adr/`.

### Agency configuration (data, not code)

```yaml
agency:
  id: uuid
  name: { en: "...", ta: "...", zh: "..." }
  timezone: "Asia/Singapore"          # IANA — drives all schedule math
  locales: [en, ta, zh, ms]
  currency: SGD                       # ISO 4217
  distance_unit: metric | imperial
  modes: [bus, rail, ferry, tram, paratransit]
  map_provider: google | maplibre | protomaps
  license: { spdx: "CC-BY-4.0", attribution: "...", terms_url: "..." }
  branding: { primary, secondary, logo_url, font }
  driver_ops:                          # see §4
    stop_geofence_m: 40
    ping_interval_moving_s: 5
    ping_interval_idle_s: 60
    auto_start_trip: true
    lock_ui_above_kmh: 5
  feeds: [ ...adapter configs... ]
```

Flutter apps read this at boot and theme themselves. White-labelling must never
require a rebuild — only a store listing.

---

## 3. Roles, Permissions & Fleet Administration

### 3.1 Role model

| Role | Scope | Can do |
|---|---|---|
| `super_admin` | Platform | Create agencies, manage deployment-wide settings |
| `agency_admin` | One agency | Everything below, plus user & role management, billing, licence config |
| `dispatcher` | One agency (or depot) | Live dispatch board, reassign duties mid-day, resolve incidents |
| `fleet_manager` | One agency | Vehicles, routes, timetables, depots — no live ops |
| `driver` | Self | Own assigned duties only |
| `data_consumer` | Own org | Portal: request datasets, manage own API keys |
| `rider` | Self | Rider app; may be anonymous |

Roles are **agency-scoped and multi-valued** — one person can be a dispatcher at
one depot and a driver at another. Model as `user_roles(user_id, agency_id,
role, depot_id nullable)`, never as a single column on the user.

**Security requirement, do not get this wrong:** roles live in a server-owned
table and are injected into the JWT via a Supabase custom access token hook,
mirrored into `app_metadata`. Never read authorisation from `user_metadata` —
that field is writable by the user themselves, so a role stored there is a
privilege-escalation hole. Every RLS policy reads the claim, and the Go API
re-checks server-side rather than trusting the client.

### 3.2 Admin console — fleet & operations

`/admin` in the portal, gated by `fleet_manager` and above:

**Vehicles** — CRUD on registration, fleet number, capacity class, accessibility
features (wheelchair ramp, low floor), propulsion type, depot, in-service status,
maintenance hold. Bulk CSV import for initial onboarding.

**Routes & timetables** — create and version routes, stop sequences, shapes, and
service calendars. This is the write path behind the `manual` adapter (§5): an
agency with no prior digital data builds its network here and Transit emits its
first GTFS feed.

**Drivers** — invite by phone or email, assign depot, record licence expiry,
suspend/reactivate. Licence expiry blocks duty assignment automatically and
warns 30 days out.

**Duty assignment** — the core scheduling screen. Assign a driver **and** a
vehicle to a `block` (GTFS `block_id`: an ordered sequence of trips one vehicle
runs in a day) for a service date.
- Conflict detection: same driver two places at once, vehicle on maintenance hold, licence expired, insufficient rest gap between shifts
- Recurring patterns: apply a weekly roster across a date range
- Mid-day reassignment and vehicle swap, with handover at a named stop
- Unassigned-block warnings before the service day starts

**Live dispatch board** — map of every active vehicle with delay colouring,
occupancy, off-route flags, and open incidents. Click a vehicle to see its ping
trace, message the driver, or reassign.

**Audit log** — every mutation records actor, timestamp, before/after, and IP.
Non-negotiable for a government product; make it append-only and exportable.

### 3.3 Assignment tables

```sql
depots            (id, agency_id, name, geog)
driver_profiles   (user_id, agency_id, depot_id, licence_ref_hash,
                   licence_expires_on, status)
blocks            (id, agency_id, block_ref, service_date, trip_ids[])
duty_assignments  (id, agency_id, block_id, driver_id, vehicle_id, service_date,
                   status, assigned_by, handover_from_id nullable)
duty_events       (assignment_id, kind, ts, actor, note)   -- signed on, swapped, ended
```

`duty_assignments` is what the driver app queries on login. One row is a shift.

---

## 4. Driver App — Always-On Operation & Zero-Touch GPS

The design target: **the driver touches the screen twice a shift.** Once to
confirm the duty, once to end it. Everything else is inferred.

### 4.1 Staying on screen

- **Wake lock** for the whole duty (`wakelock_plus`), released the moment the duty ends. Auto-dim to a night palette on a schedule or ambient light sensor — a full-brightness white screen at 2am is a road hazard.
- **Android foreground service** with a persistent notification, declared with the location foreground-service type. This is mandatory for continuous background location on modern Android and is the difference between a tracker that works and one that silently dies after ten minutes.
- **Battery optimisation exemption** requested at onboarding, plus OEM-specific guidance. Xiaomi, Huawei, Oppo, Vivo and Samsung all ship aggressive process killers with their own autostart settings; ship a per-OEM setup wizard rather than a generic "allow background activity" prompt, and detect the manufacturer to show the right instructions.
- **iOS** requires the location background mode with Always authorisation, `allowsBackgroundLocationUpdates` and `pausesLocationUpdatesAutomatically = false`, with significant-location-change as the degraded fallback. iOS will not let you run indefinitely on a wake lock alone — location must be the reason the app is alive.
- **Kiosk mode** for agency-owned devices: Android screen pinning / lock task via device owner provisioning, iOS Guided Access. Driver cannot leave the app or reach settings mid-shift.
- **Crash and reboot recovery**: an open duty and its unsent ping queue persist locally. On boot or relaunch the app restores the duty automatically and resumes without asking. Never lose a shift to a battery pull.
- **Safety interlock**: above `lock_ui_above_kmh` the UI drops to read-only — no text entry, no menus, no dialogs, occupancy buttons disabled until stopped. Many jurisdictions prohibit driver device interaction while moving, and an app that invites it will fail an operator's safety review.

### 4.2 Zero-touch GPS tracking

Everything below runs on-device so it works offline, and is **recomputed
server-side from the raw ping trace** — never trust client-derived stop events as
authoritative, since a stale or spoofed client would otherwise corrupt the
public feed.

**Trip start.** The app knows the driver's block from `duty_assignments`. When
GPS shows the vehicle leaving the origin terminal geofence within the scheduled
departure window, the trip auto-starts. Early or late departures still match;
only an implausible position or a wrong route shape suppresses it. Manual
override is available but should be rare.

**Progression along the route.** Map-match each fix to the trip's shape and
track `shape_dist_traveled` monotonically. This is what stops you registering
false arrivals from a parallel road or an opposite-direction stop across the
street — a plain nearest-stop radius check will do exactly that and it is the
single most common bug in homemade AVL.

**Stop arrival and departure.** Geofence per stop at the configured radius, plus
a dwell threshold, plus shape progression consistency. Emit GTFS-RT
`VehiclePosition.current_status` as `INCOMING_AT` / `STOPPED_AT` /
`IN_TRANSIT_TO` with `current_stop_sequence` and `stop_id` — the enums map
directly, so don't invent a parallel vocabulary.

**Delay and prediction.** Compare actual arrival against `stop_times`, compute
per-stop delay, propagate to downstream stops with decay, and publish as a
GTFS-RT `TripUpdate`. Serve the same numbers to the rider app so the two never
disagree.

**Signal quality.** Reject fixes with poor accuracy, impossible speed, or
teleport jumps. Smooth with a Kalman or equivalent filter. In tunnels and urban
canyons, hold last known position, mark it stale with an age, and let the rider
app show staleness rather than a confidently wrong marker.

**Adaptive sampling.** Ping at `ping_interval_moving_s` in motion, drop to
`ping_interval_idle_s` when stationary at a terminal, and burst near stops.
Batch into 10-ping payloads, persist to a local queue, flush on connectivity.
Assume long dead zones — a tunnel, a rural stretch, a depot basement.

**Off-route detection.** Sustained departure from the shape beyond a threshold
raises a diversion flag, notifies the dispatcher, and marks downstream
predictions low-confidence instead of publishing fiction.

**Trip and duty end.** Auto-end at the terminus geofence with dwell, or at
schedule end with no movement. The duty ends when the last block trip completes
or the driver signs off; either way the wake lock and foreground service stop.

**What stays manual.** Occupancy cannot be sensed from GPS — keep it a single
large tap using GTFS-RT `OccupancyStatus` values, permitted only when stopped.
Incident reporting is likewise one tap plus optional voice note, never typing.

---

## 5. Upstream Adapters

`services/api/internal/adapters/` — each implements one interface and normalises
to GTFS. The LTA DataMall integration is one adapter among several, not the
architecture.

| Adapter | Covers | Notes |
|---|---|---|
| `gtfs_static` | Global baseline | Zip ingest, validate, diff, version |
| `gtfs_rt` | Global baseline | Protobuf, three feed types |
| `siri` | Europe / UK | SIRI-VM, SIRI-SM, SIRI-ET |
| `netex` | EU national access points | Static counterpart to SIRI |
| `transxchange` | UK | Legacy but widespread |
| `gbfs` | Micromobility, anywhere | Bikeshare, scooters, docks |
| `datamall` | Singapore | Proprietary; the reference vendor adapter |
| `manual` | **Agencies with no digital data at all** | Timetables entered in `/admin`, vehicles tracked only by the driver app |

The `manual` adapter matters more than it looks. Minibuses, jeepneys, matatus
and marshrutkas carry enormous ridership with no published schedule in any
format. For those agencies the admin console plus the driver app is the entire
data pipeline, and Transit produces their first-ever GTFS feed.

```go
type Adapter interface {
    Name() string
    Capabilities() Capabilities        // static? realtime? fares? redistributable?
    SyncStatic(ctx, AgencyFeed) (StaticResult, error)
    PollRealtime(ctx, AgencyFeed) (<-chan RTMessage, error)
    Validate(ctx, AgencyFeed) []Diagnostic   // dry-run before an agency saves a feed
}
```

Each adapter needs exponential backoff, a circuit breaker, an upstream-latency
metric, and a `sync_runs` audit row. Upsert by natural key — never
truncate-and-reload a table the apps read. Rate-limit strategy belongs in the
adapter: DataMall's bus arrival is per-stop and on-demand so it declares
read-through-with-TTL; a SIRI-VM feed declares a 30s tick. The scheduler honours
what each adapter asks for.

---

## 6. Repository Layout

```
transit/
├── apps/
│   ├── driver_app/            # Flutter
│   ├── rider_app/             # Flutter
│   └── portal/                # Next.js (App Router + Tailwind) — public + /admin
├── packages/
│   ├── transit_core/          # Dart: entities, GTFS value objects, failures
│   ├── transit_api_client/    # Dart: GENERATED from contracts/openapi.yaml
│   ├── transit_design/        # Dart: runtime-themed design system
│   ├── transit_maps/          # Dart: map provider abstraction
│   └── transit_telemetry/     # Dart: ping queue, map-matching, geofencing
├── services/
│   └── api/
│       ├── cmd/{server,ingestor,exporter}/
│       └── internal/
│           ├── adapters/      # one package per upstream standard
│           ├── ingest/        # scheduling, normalisation, dedupe
│           ├── gtfs/          # canonical model, validation, export
│           ├── httpapi/       # handlers, auth, RBAC, keys, quotas
│           ├── store/         # sqlc-generated queries
│           ├── tracking/      # server-side map-matching, stop events, delays
│           ├── dispatch/      # duties, assignments, conflict detection
│           ├── fusion/        # merge crowdsourced + official signals
│           └── planner/       # RAPTOR itinerary engine
├── contracts/openapi.yaml
├── infra/supabase/{migrations,policies}/
├── deploy/{compose,helm,terraform}/
├── docs/{adr,onboarding}/
└── Makefile, melos.yaml, go.work
```

---

## 7. Stack (fixed)

| Layer | Choice |
|---|---|
| Apps | Flutter — Riverpod + GoRouter + freezed |
| Portal | Next.js App Router + Tailwind |
| Backend | **Go** — chi, pgx/v5, sqlc, distroless container |
| DB | **Supabase Postgres** + PostGIS + pg_cron (self-hostable) |
| Auth | **Supabase Auth**, JWT + custom claims hook, verified in Go via JWKS |
| Realtime | Supabase Realtime |
| Maps | Pluggable: MapLibre + OSM/Protomaps default, Google optional |
| Tooling | Melos + go.work + pnpm |

**On maps:** do not hard-depend on `google_maps_flutter`. Put it behind
`transit_maps` with MapLibre as the default. Google Maps is unavailable,
restricted, or politically unacceptable in enough jurisdictions that a
Google-only client cannot be sold as a government product — and self-hosted
vector tiles remove a per-request cost line from the agency's budget.

---

## 8. Data Model Notes

Canonical GTFS tables (`agencies`, `routes`, `trips`, `stops`, `stop_times`,
`calendar`, `shapes`, `fare_products`), the assignment tables in §3.3, plus:

```sql
vehicles          (id, agency_id, depot_id, fleet_no, plate_hash, capacity_class,
                   accessibility jsonb, status)
vehicle_trips     (id, agency_id, assignment_id, trip_id, vehicle_id, driver_id,
                   started_at, ended_at, start_source, end_source)
vehicle_pings     (agency_id, assignment_id, ts, geog, heading, speed, accuracy_m,
                   occupancy, matched_shape_dist, source)
stop_events       (agency_id, trip_id, stop_id, seq, arrived_at, departed_at,
                   delay_s, confidence, derived_by)
incident_reports  (id, agency_id, trip_id, kind, note, geog, ts, resolved_at)
api_keys          (id, agency_id, org_id, key_hash, scopes[], rate_limit_rpm, quota_daily)
access_requests   (id, agency_id, user_id, org_name, use_case, datasets[], status)
usage_events      (api_key_id, ts, endpoint, status, latency_ms)
audit_log         (id, agency_id, actor_id, action, entity, before, after, ts, ip)
```

`vehicle_pings` is the hot table: partition by day, retain raw for a configurable
window (default 7 days), roll up older into `stop_events` and aggregate speed
profiles. GIST on `geog`, btree on `(assignment_id, ts DESC)`.

**RLS, explicit per table:**
- Drivers insert pings only for an open duty where `driver_id = auth.uid()`
- Drivers read only their own `duty_assignments`
- Dispatchers read live pings for their agency (and depot, if scoped) — but only for currently-open duties
- Riders read only the `live_vehicles` view; raw pings are a driver-surveillance dataset and never leave the building
- Data consumers get no direct Postgres access at all; they go through the Go API with a key
- Agency admins are scoped to their own `agency_id` on every table

**Store all timestamps as `timestamptz` and do schedule arithmetic in the
agency's IANA timezone.** GTFS `stop_times` can exceed 24:00:00 for
after-midnight service, and DST transitions will silently corrupt timetables if
these are treated as naive clock times.

---

## 9. Backend Notes (Go)

- chi + slog + OpenTelemetry; types generated with `oapi-codegen`
- One auth middleware, two credential types: Supabase JWT (apps and admin, with role claims) and hashed API key (portal consumers, token-bucket limited). RBAC checks are centralised and table-driven, not scattered `if role ==` branches.
- Multi-stage Dockerfile → distroless static, CGO off, non-root, `/healthz` + `/readyz`
- **`tracking`**: re-runs map-matching and stop detection over the raw ping trace server-side. Client results are a hint; the server's version is authoritative and is what feeds GTFS-RT.
- **`dispatch`**: assignment conflict rules, licence-expiry gating, rest-gap validation, handover state machine.
- **`planner`**: RAPTOR over the in-memory timetable, not Dijkstra on a road graph — it handles time-dependent transfers correctly and is what production transit routers use. Walking legs from OSRM/Valhalla self-hosted or the configured provider, cached by rounded coordinate pair.
- **`fusion`**: official prediction wins for ETA, crowdsourced wins for occupancy, every field carries `source` + `confidence`, never silently blended. Under the `manual` adapter, driver-app telemetry is the only source and confidence reflects ping age.
- **`exporter`**: GTFS.zip on a schedule, GTFS-RT protobuf live. Run MobilityData's `gtfs-validator` in CI against fixtures and fail the build on new errors.

---

## 10. Licensing & Compliance (per agency, not hardcoded)

- Attribution string, SPDX licence and terms URL come from agency config and render in both apps' about screens, on every portal dataset page, and as an `X-Data-Source` header
- Tag every served field `source: upstream | community` so consumers can distinguish official from derived data
- Each adapter declares a `Redistributable` capability; the portal automatically hides non-redistributable datasets from external key holders
- **Driver location is personal data** under GDPR, PDPA and most equivalents, and continuous shift-long tracking is employee monitoring. Ship a documented retention policy with configurable windows, keep raw pings off the public API, restrict dispatcher visibility to open duties, purge or anonymise on duty end per policy, and give drivers a transparency screen showing exactly what is recorded and for how long. In several jurisdictions this also requires works-council or union consultation before deployment — surface it in the onboarding docs rather than letting an agency discover it after rollout.

---

## 11. Phase Plan

| Phase | Deliverable | Gate |
|---|---|---|
| 0 | Repo skeleton, melos + go.work + pnpm, Makefile, compose stack, CI lint | `make dev` boots the whole stack |
| 1 | Migrations, RLS, PostGIS, agencies + tenancy, canonical GTFS schema | RLS proven across two agencies with anon/driver/admin JWTs |
| 2 | **Roles, custom claims hook, RBAC middleware, audit log** | Privilege-escalation test suite passes |
| 3 | `gtfs_static` + `gtfs_rt` adapters, ingest scheduler, sync audit | A real public GTFS feed ingests and validates clean |
| 4 | OpenAPI v0.1 + Go read API + generated Dart client | Postman collection green |
| 5 | Rider app: map, nearby stops, arrivals, route view, runtime theming | Same binary renders two different agencies |
| 6 | **Admin console: vehicles, drivers, blocks, duty assignment, conflicts** | A week's roster can be built and published |
| 7 | **Driver app: always-on shell, foreground service, ping queue, offline duty recovery** | Survives 8h shift, airplane-mode gap, and a forced reboot |
| 8 | **Server-side tracking: map-matching, stop events, delay → GTFS-RT** | Replayed trace produces correct arrival times within tolerance |
| 9 | **Live dispatch board + off-route and incident alerts** | Reassignment mid-duty works end to end |
| 10 | `manual` adapter + GTFS/GTFS-RT export | An agency with zero prior data emits a valid GTFS.zip |
| 11 | RAPTOR planner, alerts, fares | Multi-leg trip planned correctly in two locales |
| 12 | Hardening: quotas, observability, load test, Helm chart, release CI | — |

Adapters beyond `gtfs_static` / `gtfs_rt` / `manual` are post-v1 — the interface
exists so each stays roughly a day's work.

---

## 12. Non-Negotiables Checklist

- [ ] Zero country, currency, language or vendor names outside adapters and config
- [ ] Roles never read from `user_metadata`; every RLS policy and API handler re-checks server-side
- [ ] Two agencies on one deployment cannot see each other's data — proven by test, not by inspection
- [ ] Driver app survives an 8-hour shift with the screen on, a reboot, and a 40-minute connectivity gap without losing a duty
- [ ] Stop events are recomputed server-side; client-derived events are never published directly
- [ ] Driver UI is read-only above the configured speed threshold
- [ ] Raw ping traces are unreachable from any public endpoint or rider-facing view
- [ ] Every admin mutation lands in an append-only audit log
- [ ] Generated GTFS passes MobilityData validation in CI
- [ ] No service-role Supabase key ever ships in a client binary
- [ ] Migrations forward-only and idempotent; `make test` runs Dart, Go and portal suites

---

## 13. Start Here

Execute **Phase 0 only**. Print the resulting tree plus the contents of
`Makefile`, `melos.yaml`, `go.work`, and `deploy/compose/compose.yaml`. Then stop
and ask for approval.
