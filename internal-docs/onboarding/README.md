# Onboarding a new agency

Phase 12 hardening deliverable (build brief §12's "clean-checkout →
`make dev` → seeded demo works per onboarding doc, verified by someone who
didn't write the code" gate). This guide gets an agency from "nothing" to
a working deployment; it assumes the reader has never touched this
codebase.

## Before you start: the works-council / union consultation (read this first)

**Driver location is personal data under GDPR, PDPA and most equivalents,
and continuous shift-long GPS tracking is employee monitoring** — that's
the build brief's own framing (§10), not a legal opinion this document is
qualified to give. What this codebase actually does, concretely, so your
works council or union has something specific to evaluate rather than a
vague "we track drivers":

- **Tracking is duty-scoped, not always-on.** The driver app only records
  location while a duty is signed on (`apps/driver_app`'s foreground
  service starts on duty confirm, stops on duty end) — never in the
  background outside a shift, and never before the driver has confirmed
  they're starting one.
- **Raw traces are not public and not permanent.** They're unreachable
  from any public or rider-facing endpoint (proven by test — see
  `docs/SECURITY_REVIEW.md`), visible only to dispatchers/fleet managers
  for *currently open* duties, and retained for a configurable window
  (`driver_ops` in agency config — see below) after which only aggregated
  arrival/delay data survives, not the individual GPS trace.
- **Drivers see exactly what's recorded.** The driver app's "What we
  record" screen (`apps/driver_app/lib/screens/transparency_screen.dart`)
  is a plain-language disclosure of all of the above, shown in-app — not
  buried in a policy document a driver never opens.
- **Several jurisdictions legally require works-council or union
  consultation before this kind of monitoring goes live** — this is a
  process step, not a technical one, and it needs to happen *before*
  rollout, not discovered after a driver complains. Bring: the retention
  window you intend to configure, who at your agency has dispatcher-level
  visibility into live positions, and the transparency screen's exact text
  (screenshot it) — those are the three concrete facts a consultation
  needs to evaluate.

Only once that conversation has happened (or your jurisdiction doesn't
require it — confirm this, don't assume it) should driver telemetry go
live for real drivers. Nothing in this codebase gates that on a checkbox —
it's a process obligation, not a software one, hence documenting it here
rather than trying to build a "consultation completed" flag into the app.

## 1. Prerequisites

- Docker (for `deploy/compose/compose.yaml`'s local stack)
- Go 1.26+, Flutter 3.x, Node 20+/pnpm (only if you're building from
  source rather than pulling published images)

## 2. Clean-checkout smoke test

```
git clone <this repo>
cd transit
cp .env.example .env
make dev
```

This boots Postgres (with PostGIS) and the Go API. `curl
localhost:8080/healthz` should return 200. This is the exact gate build
brief §12 names — **run it yourself, on a machine that didn't write this
code**, before trusting anything else in this guide.

For the full stack including Supabase Auth/REST/Realtime:
`make dev-full` instead.

## 3. Seed the demo agency and explore it

```
make db.migrate
make db.seed
```

This creates `demo-metro`, a fictional agency with a small seeded GTFS
network — the same fixture every phase's integration tests run against.
Point the rider app or a browser at
`http://localhost:8080/v0/agencies/demo-metro` to confirm it's there.

## 4. Configure your real agency

Every agency's identity, locale(s), currency, branding, map provider and
driver-ops policy is one JSON document — nothing about a specific agency
is hardcoded in code (build brief's non-negotiable #1). Validate it
against `infra/supabase/schemas/agency_config.json` before loading it; the
schema is authoritative, not this document.

Fields worth deciding deliberately before go-live, not defaulting blindly:

- **`locales`**: every language you'll actually author service alerts and
  display agency names in — the rider/driver apps and the alerts pipeline
  fall back to `"en"` or alphabetically-first when a specific translation
  is missing, so an incomplete `locales` list doesn't break anything, but
  it does mean some riders see the wrong language.
- **`driver_ops.stop_geofence_m` / `ping_interval_moving_s` /
  `ping_interval_idle_s`**: these directly trade off location precision
  against driver device battery drain and data usage — pick them with
  input from actual drivers on your fleet's device hardware, not just
  fleet-ops preference.
- **`driver_ops.lock_ui_above_kmh`**: the speed above which the driver
  app's UI goes read-only (a safety control, not a tracking one) —
  confirm this matches your jurisdiction's distracted-driving guidance.
- **`license`**: `spdx`, `attribution`, and `terms_url` — these render on
  every portal dataset page and as the `X-Data-Source` header on public
  API responses (build brief §10). Get this right before publishing your
  `/datasets` page; it's what tells downstream consumers what they're
  legally allowed to do with your data.

## 5. Get your network into the system

Three paths, depending on what you already have:

- **You already publish GTFS/GTFS-RT**: point the `gtfs_static`/`gtfs_rt`
  adapters (`cmd/ingestor`) at your existing feed URLs via the `feeds`
  table — Phase 3.
- **You have no digital data at all**: use the `manual` adapter (Phase
  10) — build your network in the admin console (`/admin/routes`), and
  `cmd/exporter` emits standards-compliant GTFS/GTFS-RT from it
  automatically. This is the path the build brief's Phase 10 gate ("an
  agency with zero prior data emits a valid GTFS.zip") was written for.
- **Somewhere in between**: import what you have via the CSV import on
  `/admin/vehicles`/`/admin/drivers`, hand-build the route network, and
  let driver-app telemetry (once drivers are onboarded per §0 above)
  backfill realtime data.

## 6. Deploy

Step-by-step deployment guides, from a laptop up to a real production
rollout:

- **[Deploying locally](../runbooks/deploy-local.md)** — `make dev`, the
  full stack, running the Flutter apps and portal against it.
- **[Deploying the dev/staging cloud environment](../runbooks/deploy-dev-staging.md)**
  — provisioning `deploy/terraform/environments/reference` and installing
  `deploy/helm/transit`.
- **[Deploying to production](../runbooks/deploy-production.md)** — what's
  stricter for a real, customer-facing environment.
- **[Upgrading & releasing](../runbooks/upgrading.md)** — versioning, the
  `vX.Y.Z` tag → GHCR image pipeline, and rolling a new release out.
- **Backups**: set up the CronJob in
  [`backup-restore.md`](../runbooks/backup-restore.md) before go-live, not
  after an incident.
- **Observability**: `deploy/observability/README.md` — traces are wired
  into every binary already; point `OTEL_EXPORTER_OTLP_ENDPOINT` at a
  collector once you have one.

None of the deploy artifacts above were installed against a real cluster
in the session that wrote them — dry-run every one of them (`terraform
plan`, `helm template`) before trusting them for a production rollout.

## 7. Before real drivers start a real duty

- The works-council/union step from §0, done.
- `docs/SECURITY_REVIEW.md` reviewed against your actual deployment
  (roles, RLS, audit logging) — it documents what's proven by test in
  this codebase, not what's true of your specific configuration.
- A backup taken and a restore drill run at least once
  (`docs/runbooks/backup-restore.md`) — the first time you test a restore
  procedure should not be during an actual incident.
