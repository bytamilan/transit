# Driver App (Flutter) — Phase 7

Mounted, always-on, near-zero-interaction terminal. The phone *is* the AVL
system. See `docs/BUILD_PROMPT.md` §4 (always-on operation, zero-touch GPS).

## What's here

- `lib/screens/`: login → onboarding (location + battery-exemption + per-OEM
  autostart wizard + kiosk-mode guidance) → duty list → active-shift screen
  → transparency screen.
- `lib/services/foreground_service.dart`: the Android foreground
  service / iOS background-fetch entry point. Runs in its own isolate
  (Android) so tracking survives the UI being backgrounded, the app being
  swiped away, or (via `autoStartOnBoot`) a device reboot — it re-derives
  everything it needs from `RecoveryStore` (SharedPreferences) and the
  network rather than sharing state with the UI isolate.
- `lib/services/duty_block_loader.dart`: resolves a duty's block into an
  ordered stop sequence via the public `/v0` read API (Phase 4) — there is
  no shapes.txt read endpoint yet, so the "shape" for map-matching is the
  straight line through consecutive stops, the same degraded-but-workable
  fallback GTFS tooling uses for a feed with no shapes.txt at all.
- `packages/transit_telemetry`: the on-device tracking primitives (adaptive
  sampling, GPS smoothing, junk-fix rejection, shape map-matching, trip/stop
  detection, persistent ping queue) — pure Dart, unit tested, no Flutter
  dependency.
- `android/app/src/main/AndroidManifest.xml` /
  `ios/Runner/Info.plist`: background location permissions, the
  `location`-typed Android foreground service, and iOS's `location`
  background mode.

## Known limitation

Verified with `flutter analyze`, `flutter test`, and a successful
`flutter build apk --debug` — but **not exercised on a real device**. The
always-on shell, background survival, per-OEM autostart wizard, and the
Phase 7 gate (8h shift, forced reboot, 40-minute airplane-mode gap without
losing a duty or a ping) all need real-device testing before this phase can
be marked done. An iOS build was not attempted. See `docs/PHASE_PLAN.md`
Phase 7.

## Local development

```sh
cd apps/driver_app
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=...
```
