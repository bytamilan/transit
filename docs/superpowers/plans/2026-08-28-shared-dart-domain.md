# Shared Dart Domain, Runtime Theme, and Map Providers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete `transit_core`, finish runtime theming and map-provider selection, and wire both Flutter apps to validated shared domain types.

**Architecture:** Generated OpenAPI models remain transport-only. `transit_api_client` maps them into pure-Dart `transit_core` entities and value objects; the apps consume those domain types. `transit_design` builds runtime agency themes, while `transit_maps` resolves MapLibre/Protomaps by default and accepts an optional external Google provider without importing a Google SDK.

**Tech Stack:** Dart 3, Flutter, Riverpod, built_value-generated OpenAPI client, MapLibre GL, Flutter widget/unit tests, Melos workspace.

**Spec:** `docs/superpowers/specs/2026-08-28-shared-dart-domain-design.md`

## Global Constraints

- `transit_core` is pure Dart and has no Flutter, Dio, or map SDK dependencies.
- Generated files under `packages/transit_api_client/lib/src/model/*.g.dart` and generated model files are not hand-edited.
- White-labelling comes from agency config at boot/runtime and never requires a rebuild.
- MapLibre + OSM/Protomaps is the default; `google_maps_flutter` must not appear in any dependency or import.
- GTFS times may exceed `24:00:00`; parsing must preserve elapsed time after midnight.
- Invalid required domain data produces a typed `ValidationFailure`.
- Every implementation task follows red-green-refactor: write a failing test, run it, implement the minimum, run it again, then refactor.

---

### Task 1: Scaffold `transit_core` and its failure/value-object API

**Files:**
- Create: `packages/transit_core/pubspec.yaml`
- Create: `packages/transit_core/analysis_options.yaml`
- Create: `packages/transit_core/lib/transit_core.dart`
- Create: `packages/transit_core/lib/src/failures/failure.dart`
- Create: `packages/transit_core/lib/src/value_objects/gtfs_id.dart`
- Create: `packages/transit_core/lib/src/value_objects/localized_text.dart`
- Create: `packages/transit_core/lib/src/value_objects/gtfs_time.dart`
- Create: `packages/transit_core/lib/src/value_objects/geo_point.dart`
- Test: `packages/transit_core/test/failure_test.dart`
- Test: `packages/transit_core/test/value_objects_test.dart`

**Interfaces:**
- Produces `GtfsId(String value)`, `LocalizedText(Map<String, String> values)`, `GtfsTime.parse(String)`, and `GeoPoint({required double latitude, required double longitude})`.
- Produces sealed `Failure` subclasses and `TransitException(Failure failure)`.

- [ ] **Step 1: Write failing value-object tests.** Assert that `GtfsId(' stop ')` stores `stop`, empty IDs throw `ValidationFailure`, `LocalizedText.pick('ta')` prefers Tamil then English then sorted first locale, `GtfsTime.parse('25:30:00').toDuration()` equals 25 hours 30 minutes, invalid minute/second fields throw, and `GeoPoint` rejects latitude 91 and longitude 181.
- [ ] **Step 2: Run the focused tests.** From `packages/transit_core`, run `dart test test/value_objects_test.dart test/failure_test.dart`. Expected: failure because the package and symbols do not exist.
- [ ] **Step 3: Implement the pure-Dart package and minimal types.** Use immutable `final` fields, defensive `Map.unmodifiable`/`List.unmodifiable` copies, value equality/hashCode, `Comparable<GtfsTime>` by duration, and `ValidationFailure` for constructor/parser failures. `GtfsTime.toString()` must emit two-digit minutes/seconds and preserve hours above 23.
- [ ] **Step 4: Run the focused tests again.** Expected: all value-object and failure tests pass.
- [ ] **Step 5: Commit the package foundation.** Run `git add packages/transit_core && git commit -m "feat(core): add failures and GTFS value objects"`.

### Task 2: Add shared agency/configuration and GTFS entities

**Files:**
- Create: `packages/transit_core/lib/src/entities/agency.dart`
- Create: `packages/transit_core/lib/src/entities/agency_config.dart`
- Create: `packages/transit_core/lib/src/entities/gtfs_entities.dart`
- Modify: `packages/transit_core/lib/transit_core.dart`
- Test: `packages/transit_core/test/agency_config_test.dart`
- Test: `packages/transit_core/test/gtfs_entities_test.dart`

**Interfaces:**
- Produces `Agency`, `AgencyBranding`, `AgencyLicense`, `DriverOpsConfig`, and `AgencyConfig` with `fromJson(Map<String, dynamic>)` factories.
- Produces `DistanceUnit { metric, imperial }` and `MapProviderKind { google, maplibre, protomaps }` with safe string parsing.
- Produces `Stop`, `Route`, `Trip`, and `StopTime`; stop coordinates are `GeoPoint?`, and stop-time arrival/departure fields are `GtfsTime?`.

- [ ] **Step 1: Write failing entity/config tests.** Build an agency config fixture containing all contract fields and assert round-trip field values, `map_provider: 'protomaps'`, driver defaults, localized agency names, and GTFS entity equality. Add tests that missing required agency/config/entity fields and invalid coordinates produce `ValidationFailure`.
- [ ] **Step 2: Run the focused tests.** From `packages/transit_core`, run `dart test test/agency_config_test.dart test/gtfs_entities_test.dart`. Expected: failure because the entities are absent.
- [ ] **Step 3: Implement the entities and raw JSON factories.** Keep field names aligned with GTFS/API vocabulary, use immutable collections, default optional branding secondary color to `#FFFFFF`, default driver operations to the contract defaults (`40`, `5`, `60`, `true`, `5`), and parse unknown map-provider strings as `MapProviderKind.maplibre`.
- [ ] **Step 4: Run the focused tests.** Expected: all entity/config tests pass.
- [ ] **Step 5: Commit the shared domain entities.** Run `git add packages/transit_core && git commit -m "feat(core): add agency and GTFS entities"`.

### Task 3: Add generated-API-to-domain adapters

**Files:**
- Modify: `packages/transit_api_client/pubspec.yaml`
- Create: `packages/transit_api_client/lib/src/domain_mappers.dart`
- Modify: `packages/transit_api_client/lib/transit_api_client.dart`
- Test: `packages/transit_api_client/test/domain_mappers_test.dart`

**Interfaces:**
- Consumes the Task 2 core types and generated transport types imported with aliases `package:transit_api_client/... as api`.
- Produces extensions `api.Agency.toDomain()`, `api.AgencyConfig.toDomain()`, `api.AgencyBranding.toDomain()`, `api.AgencyLicense.toDomain()`, `api.DriverOpsConfig.toDomain()`, `api.Stop.toDomain()`, `api.Route.toDomain()`, `api.Trip.toDomain()`, and `api.StopTime.toDomain()`.

- [ ] **Step 1: Write failing adapter tests.** Build generated `Agency`, `AgencyConfig`, `Stop`, and `StopTime` fixtures, call `.toDomain()`, and assert mapped IDs, enums, coordinates, and `GtfsTime`. Add a stop fixture with latitude 91 and a stop-time fixture with `25:30:00` plus malformed `25:60:00`; assert the invalid cases throw `TransitException` containing `ValidationFailure`.
- [ ] **Step 2: Run the focused tests.** From `packages/transit_api_client`, run `dart test test/domain_mappers_test.dart`. Expected: failure because the extensions and dependency are absent.
- [ ] **Step 3: Implement adapters without touching generated files.** Add the path dependency on `../transit_core`, convert `BuiltMap`/`BuiltList` using ordinary immutable Dart collections, map generated enum names explicitly, and wrap `FormatException`, `ArgumentError`, and type errors in `TransitException(ValidationFailure(...))`.
- [ ] **Step 4: Run the focused tests.** Expected: all adapter tests pass.
- [ ] **Step 5: Commit the adapters.** Run `git add packages/transit_api_client && git commit -m "feat(api): map generated models to core domain"`.

### Task 4: Complete runtime agency theming

**Files:**
- Modify: `packages/transit_design/pubspec.yaml`
- Modify: `packages/transit_design/lib/src/agency_theme.dart`
- Modify: `packages/transit_design/lib/src/theme_provider.dart`
- Modify: `packages/transit_design/lib/transit_design.dart`
- Test: `packages/transit_design/test/agency_theme_test.dart`
- Test: `packages/transit_design/test/theme_provider_test.dart`

**Interfaces:**
- Consumes `transit_core.AgencyConfig`.
- Produces `AgencyTheme.fromConfig(AgencyConfig)`, `AgencyTheme.toTheme({Brightness brightness = Brightness.light})`, and the existing JSON constructor for compatibility.
- `ThemeProvider.updateShouldNotify` compares primary, secondary, logo URL, and font.

- [ ] **Step 1: Write failing theme tests.** Assert `#123456` becomes opaque `Color(0xFF123456)`, `#80123456` preserves alpha, malformed colors use defaults without throwing, `AgencyTheme.fromConfig` copies all branding fields, and changing only `font` or `logoUrl` makes `ThemeProvider` notify.
- [ ] **Step 2: Run the focused tests.** Run `flutter test packages/transit_design/test`. Expected: failure for the new config constructor/notification behavior.
- [ ] **Step 3: Implement safe runtime theme construction.** Add the core dependency, parse only six/eight-digit hex values, make invalid values use `#000000`/`#FFFFFF`, include all branding fields in equality/notifications, and preserve Material 3 color-scheme/text-theme behavior for light and dark modes.
- [ ] **Step 4: Run the focused tests.** Expected: all design package tests pass.
- [ ] **Step 5: Commit runtime theming.** Run `git add packages/transit_design && git commit -m "feat(design): apply agency branding at runtime"`.

### Task 5: Finish map primitives, MapLibre rendering, and provider resolution

**Files:**
- Modify: `packages/transit_maps/pubspec.yaml`
- Modify: `packages/transit_maps/lib/src/map_provider.dart`
- Modify: `packages/transit_maps/lib/src/map_view.dart`
- Create: `packages/transit_maps/lib/src/provider_resolver.dart`
- Modify: `packages/transit_maps/lib/transit_maps.dart`
- Test: `packages/transit_maps/test/provider_resolver_test.dart`
- Test: `packages/transit_maps/test/map_primitives_test.dart`

**Interfaces:**
- Consumes `transit_core.MapProviderKind`.
- Produces immutable `MapViewOptions`, `MapMarker`, `MapPolyline`, and `MapPoint`, plus `MapProvider.buildMap(MapViewOptions options)`.
- Produces `MapProviderResolver({required MapProvider mapLibre, MapProvider? protomaps, MapProvider? google})` and `MapProvider resolve(MapProviderKind kind)`.

- [ ] **Step 1: Write failing resolver/primitive tests.** Assert resolver returns the registered provider for MapLibre, Protomaps, and Google; missing Google falls back to MapLibre; map primitive lists cannot be mutated through the input list; and equality reflects all fields.
- [ ] **Step 2: Run the focused tests.** Run `flutter test packages/transit_maps/test`. Expected: failure because the new options/resolver API is absent.
- [ ] **Step 3: Implement the provider boundary.** Add the core dependency, update existing app/test provider implementations to accept `MapViewOptions`, make constructors `const` where possible, have `MapLibreProvider` use configurable style URLs, forward `onMapClick`, add symbols from markers, and add MapLibre lines from polyline points using `LineOptions`.
- [ ] **Step 4: Run the focused tests and dependency check.** Run `flutter test packages/transit_maps/test` and `rg -n "google_maps_flutter" packages/transit_maps packages/transit_core packages/transit_design`. Expected: tests pass and the search returns no matches.
- [ ] **Step 5: Commit map abstraction.** Run `git add packages/transit_maps && git commit -m "feat(maps): resolve runtime map providers"`.

### Task 6: Wire rider app to shared config, domain models, and runtime map selection

**Files:**
- Modify: `apps/rider_app/pubspec.yaml`
- Modify: `apps/rider_app/lib/models/app_state.dart`
- Modify: `apps/rider_app/lib/providers/agency_provider.dart`
- Modify: `apps/rider_app/lib/app.dart`
- Modify: `apps/rider_app/lib/screens/home_screen.dart`
- Modify: `apps/rider_app/lib/screens/route_screen.dart`
- Modify: `apps/rider_app/test/golden/fixtures.dart`
- Modify: `apps/rider_app/test/golden/home_screen_test.dart`
- Modify: `apps/rider_app/test/golden/route_screen_test.dart`
- Create: `apps/rider_app/test/runtime_config_test.dart`

**Interfaces:**
- `AppState` stores `transit_core.Agency`, `transit_core.AgencyConfig`, and `Failure?`.
- `AgencyNotifier.loadAgency` maps `response.data!.toDomain()` for both agency and config.
- Screens retain `MapProvider? mapProvider` test injection; production resolution is `MapProviderResolver(...).resolve(config.mapProvider)`.

- [ ] **Step 1: Write failing rider runtime tests.** Assert a loaded `AgencyConfig` produces the configured theme and that a `protomaps` config resolves to the registered Protomaps provider while an unregistered Google config resolves to MapLibre. Update fake map providers in golden fixtures to implement `buildMap(MapViewOptions options)`.
- [ ] **Step 2: Run focused rider tests.** Run `flutter test apps/rider_app/test/runtime_config_test.dart`. Expected: failure because app state and screens still use generated types/direct MapLibre construction.
- [ ] **Step 3: Implement rider integration.** Add `transit_core`, use API `.toDomain()` adapters, store typed failures, derive `AgencyTheme.fromConfig`, resolve maps from `agency.config?.mapProvider` while honoring injected test providers, and replace branding-presence coordinate checks with an explicit configured/default camera position.
- [ ] **Step 4: Run focused and golden tests.** Run `flutter test apps/rider_app/test/runtime_config_test.dart apps/rider_app/test/golden`. Expected: runtime tests and existing goldens pass.
- [ ] **Step 5: Commit rider wiring.** Run `git add apps/rider_app && git commit -m "feat(rider): consume shared domain and runtime providers"`.

### Task 7: Wire driver app to shared agency/config types and runtime theme

**Files:**
- Modify: `apps/driver_app/pubspec.yaml`
- Modify: `apps/driver_app/lib/models/agency_info.dart`
- Modify: `apps/driver_app/lib/app.dart`
- Modify: `apps/driver_app/lib/services/driver_api.dart`
- Modify: `apps/driver_app/test/golden/fixtures.dart`
- Create: `apps/driver_app/test/runtime_theme_test.dart`

**Interfaces:**
- `AgencyInfo` stores `transit_core.Agency agency` and `transit_core.AgencyConfig config`; compatibility getters expose `slug`, `stopGeofenceM`, `pingIntervalMovingS`, `pingIntervalIdleS`, `autoStartTrip`, and `lockUiAboveKmh`.
- `AgencyInfo.fromJson` uses core raw JSON factories for the `/driver/agency` response.
- `DriverApp` derives light/dark `ThemeData` from `AgencyTheme.fromConfig` while applying `isNightPaletteProvider` as the theme mode.

- [ ] **Step 1: Write failing driver runtime-theme tests.** Assert the driver app’s agency branding changes the primary color and font in the built theme, missing branding uses defaults, and existing driver operation getters still return the configured values.
- [ ] **Step 2: Run the focused test.** Run `flutter test apps/driver_app/test/runtime_theme_test.dart`. Expected: failure because the driver app uses fixed indigo themes and raw config maps.
- [ ] **Step 3: Implement driver integration.** Add `transit_core`, replace raw config access with domain config, have `DriverApp` watch `agencyInfoProvider` and use its config when available with the shared default theme while loading, keep `DutyBlockLoader` and foreground tracking getters source-compatible, use `ThemeData` from the shared theme for both brightnesses, and leave the scheduled night palette behavior unchanged.
- [ ] **Step 4: Run focused and existing driver tests.** Run `flutter test apps/driver_app/test/runtime_theme_test.dart apps/driver_app/test`. Expected: all driver tests and goldens pass.
- [ ] **Step 5: Commit driver wiring.** Run `git add apps/driver_app && git commit -m "feat(driver): apply shared runtime agency theme"`.

### Task 8: Full workspace verification and cleanup

**Files:**
- Modify only files revealed by analyzer/test failures from Tasks 1–7.

- [ ] **Step 1: Refresh dependencies.** Run `flutter pub get` in `packages/transit_core`, `packages/transit_design`, `packages/transit_maps`, `packages/transit_api_client`, `apps/rider_app`, and `apps/driver_app`.
- [ ] **Step 2: Analyze every Dart package/app.** Run `dart analyze packages/transit_core packages/transit_api_client` and `flutter analyze packages/transit_design packages/transit_maps apps/rider_app apps/driver_app`. Expected: zero errors and zero warnings introduced by these changes.
- [ ] **Step 3: Run every Dart test suite.** From each package/app directory, run `flutter test` for `packages/transit_design`, `packages/transit_maps`, `apps/rider_app`, and `apps/driver_app`; run `dart test` for `packages/transit_core` and `packages/transit_api_client`. Expected: all tests pass.
- [ ] **Step 4: Verify dependency constraints.** Run `rg -n "google_maps_flutter" packages apps` and inspect each affected `pubspec.lock`; expected: no matches. Run `git diff --check`.
- [ ] **Step 5: Review the final diff against the spec.** Check that the core package is pure Dart, generated API files are unchanged, runtime theme/map selection is config-driven, and typed failures are used at the app boundary.
- [ ] **Step 6: Commit any verified cleanup.** Run `git add packages apps && git commit -m "chore: verify shared Dart package integration"` only after the complete verification commands report success.

## Self-review

- Core package scaffold, value objects, failures, entities, and exports are covered by Tasks 1–2.
- Generated transport-to-domain conversion is covered by Task 3 without editing generated files.
- Runtime theming and notification behavior are covered by Task 4 and both app integration tasks.
- MapLibre default behavior, Protomaps style configuration, optional Google registration, and the no-Google-dependency check are covered by Task 5 and Task 8.
- Rider and driver runtime configuration flows are covered by Tasks 6–7.
- Existing tests/goldens and full analyze/test verification are covered by Task 8.
- All cross-task interfaces are defined and every spec requirement maps to at least one implementation task.
