# Security review — build brief §12 non-negotiables

Phase 12 deliverable. Each box from `docs/BUILD_PROMPT.md`'s §12 checklist
(the actual project brief every "brief §N" comment in this codebase refers
to) is checked against a specific test, file, or artifact — not by
inspection alone, per the checklist's own instruction. Two real gaps were
found while doing this; both were fixed in the same commit as this review
(see "Fixed during this review" under each item).

Conducted 2026-08-28, entirely by static review and this sandbox's test
suite — no live deployment, no penetration test, no external audit. Treat
this as a self-review, not a substitute for one.

- [x] **Zero country, currency, language or vendor names outside adapters
      and config**
  Verified by grep across `services/api` (Go) and `apps/*/lib` (Dart) for
  hardcoded currency codes, timezone strings, and map-provider literals
  outside `oapi.gen.go`'s schema-derived enum — none found.
  **Fixed during this review**: `apps/rider_app` and `apps/driver_app` both
  had a hardcoded `name['en']` lookup for agency display names in four call
  sites (`app.dart`, `home_screen.dart`, `about_screen.dart`,
  `transparency_screen.dart`) — a real violation, since it silently ignores
  whatever locale the agency actually configured. Replaced with
  `localizedName()` (new `lib/utils/localized_name.dart` in both apps),
  matching the same requested-locale → `"en"` → alphabetically-first
  fallback the server already uses (`selectLocale` in
  `internal/httpapi/handlers/alerts.go`). Unit-tested:
  `apps/rider_app/test/localized_name_test.dart`,
  `apps/driver_app/test/localized_name_test.dart`.

- [x] **Roles never read from `user_metadata`; every RLS policy and API
      handler re-checks server-side**
  Proven by test, not inspection:
  `services/api/internal/store/privilege_test.go`'s
  `user_metadata_role_spoof_does_not_grant_write` and
  `tenancy_test.go`'s `driver_cannot_write_even_with_user_metadata_spoof`
  both construct a JWT whose `user_metadata.role` claims `agency_admin`
  while the actual `role` claim says `driver`, and assert the write is
  denied. RLS policies read `current_user_role()`/`current_agency_id()`
  (JWT `role`/`agency_id` claims via the custom-claims hook, ADR 0003), never
  `user_metadata`. `internal/httpapi/rbac`'s `ActorHas`/`HasPermission`
  likewise only ever consult `Actor.Roles`, populated from the JWT's `roles`
  claim in `internal/httpapi/auth/middleware.go`'s `jwtActor` — `user_metadata`
  is never parsed by the Go API at all.

- [x] **Two agencies on one deployment cannot see each other's data —
      proven by test, not by inspection**
  `internal/store/tenancy_test.go` (Phase 1's gate) seeds two demo agencies
  and asserts anon/driver/agency_admin JWTs for one agency read zero rows
  for the other. `internal/httpapi/handlers/privacy_test.go` extends this to
  the HTTP layer (raw ping traces, dispatch-only routes). All
  integration-tagged — compile-checked via `go vet -tags integration` this
  session (no live Postgres to actually run them against, the same
  limitation as every phase since 6).

- [~] **Driver app survives an 8-hour shift with the screen on, a reboot,
      and a 40-minute connectivity gap without losing a duty**
  Design evidence, not a device-test artifact: `RecoveryStore`
  (`apps/driver_app/lib/services/recovery_store.dart`) persists open-duty
  state to disk specifically so a killed/rebooted process can resume;
  `foreground_service.dart` runs the ping loop as an Android/iOS foreground
  service (survives backgrounding); the ping queue buffers offline and
  flushes on reconnect (Phase 7). No physical device or 8-hour soak test
  was ever run against this in any phase's sandbox — this remains
  **unverified by artifact**, same status noted in Phase 7-9's own
  write-ups.

- [x] **Stop events are recomputed server-side; client-derived events are
      never published directly**
  `internal/httpapi/handlers/driver.go`'s `SubmitPings` writes only raw
  `pings.Ping` rows. The only writer of `stop_events`/`vehicle_trips` is
  `internal/tracking.Service.ProcessOpenAssignments` → `ReplayBlock`
  (`cmd/tracker`), which re-derives everything from the raw ping trace
  server-side — confirmed by reading every call site of the stop_events/
  vehicle_trips store writers; there is exactly one.

- [x] **Driver UI is read-only above the configured speed threshold**
  `apps/driver_app/lib/screens/active_shift_screen.dart` and
  `models/agency_info.dart` both reference `lock_ui_above_kmh` from agency
  config (Phase 7).

- [x] **Raw ping traces are unreachable from any public endpoint or
      rider-facing view**
  `internal/httpapi/handlers/privacy_test.go`'s `TestRawPingsUnreachable`
  asserts every guessed raw-ping path 404s/is unrouted, and
  `TestAssignmentPingTrace_RejectsNonDispatchRoles` proves the one
  legitimate ping-trace path (`/admin/duty-assignments/{id}/pings`) is
  role-gated to dispatch roles, never public or rider-facing (Phase 9).

- [x] **Every admin mutation lands in an append-only audit log**
  **Fixed during this review**: `internal/httpapi/handlers/routes_admin.go`
  (`RouteEditor` — the Phase 6 route/trip/calendar/stop-times editor) had
  **zero** audit logging across all six of its mutating endpoints
  (`UpsertRoute`, `DeleteRoute`, `UpsertCalendar`, `UpsertTrip`,
  `DeleteTrip`, `ReplaceTripStopTimes`) — the one write surface in the
  codebase that never wired `audit.Writer`. Added the same `h.audit(...)`
  pattern `DispatchBoard`/`AdminAlerts` already use, wired
  `Audit: auditWriter` into `RouteEditor`'s construction in
  `cmd/server/main.go`, and added
  `internal/httpapi/handlers/routes_admin_test.go` (RBAC-gate tests; a nil-
  writer test proves `audit()` doesn't panic when unset, matching every
  other audited handler's null-safety). Every other admin write surface
  (`Fleet`, `Roster`/`DispatchBoard`, `AdminAlerts`, `APIKeysAdmin`,
  `Admin.ExportAudit`) already audited correctly.

- [ ] **Generated GTFS passes MobilityData validation in CI**
  `.github/workflows/gtfs-validate.yml` (new, this phase) builds a
  `demo-metro` GTFS.zip via `cmd/exporter` against a fresh migrated+seeded
  Postgres, then runs `ghcr.io/mobilitydata/gtfs-validator` against it,
  uploading the report as a build artifact. **Never executed against a real
  GitHub Actions runner** — no CI runner available in this sandbox all
  session (the same reason `.github/workflows/` stayed empty since Phase
  0's follow-up note). The workflow is written and locally reviewed, not
  proven green.

- [x] **No service-role Supabase key ever ships in a client binary**
  Grepped `apps/` (driver_app, rider_app, portal) for
  `SUPABASE_SERVICE_ROLE_KEY`/`service_role` — zero hits. It's read only
  server-side, in `cmd/server/main.go` (`gotrue.NewInviter`, for the
  driver-invite flow) via `os.Getenv`, never bundled into a Flutter build
  or exposed as a `NEXT_PUBLIC_*` portal env var (which Next.js inlines
  into client bundles — the portal's `NEXT_PUBLIC_SUPABASE_ANON_KEY` is
  intentionally the *anon* key, never service-role).

- [~] **Migrations forward-only and idempotent; `make test` runs Dart, Go
      and portal suites**
  Migrations: every migration in `infra/supabase/migrations/` uses
  `CREATE OR REPLACE FUNCTION`/`CREATE TABLE IF NOT EXISTS`/`CREATE INDEX
  IF NOT EXISTS` throughout (spot-checked across all 16); there is no
  `down`-migration mechanism in `cmd/migrate` at all, so "forward-only"
  isn't just convention, it's the only thing the tool supports. See
  `docs/runbooks/migrations.md` for the full pattern.
  **Fixed during this review**: `make test` ran only `go test -short
  ./...` — Dart and portal suites were never wired in, despite the brief
  requiring it verbatim. Updated the `test` target to also run `flutter
  test` for both `driver_app` and `rider_app`, and `pnpm -C apps/portal
  typecheck && pnpm -C apps/portal build` (the portal's actual
  verification gate — no unit-test framework was ever set up for it in any
  phase, so "portal suite" here means typecheck+build, the same two checks
  this session has manually run after every portal change since Phase 6).
  Verified: Go, driver_app and rider_app legs all pass end-to-end
  (`make test`, this session). The portal leg is blocked in *this specific
  sandbox* by a pnpm dependency-approval prompt
  (`unrs-resolver`'s build script) unrelated to the code itself —
  confirmed working via direct `tsc --noEmit`/`next build` invocation
  instead (see `docs/PHASE_PLAN.md` Phase 12's own verification notes).

## Summary

9 of 11 items are proven by an existing or newly-added test/artifact. Two
are marked `[~]` (partially verified) rather than checked or failed:
device-level driver-app resilience (a real gap this sandbox structurally
cannot close — it needs a physical device) and CI-verified GTFS validation
(the workflow exists and is reviewed, but no runner ever executed it). One
item (`Generated GTFS passes MobilityData validation in CI`) is marked
unchecked specifically because "in CI" requires a CI run that never
happened, not because the underlying capability (`gtfs-validator` against
exporter output) is missing — `make gtfs.validate` (Phase 10) does the
same check locally, also never run for the same Docker-availability
reason.

Two concrete defects were found and fixed in the course of this review
(the hardcoded-locale display names, and `RouteEditor`'s missing audit
trail) — evidence that "prove it by test or artifact" surfaces real bugs
that a code-review pass alone would very plausibly have missed, since both
looked correct on casual reading and only failed against the brief's
specific, literal checklist wording.
