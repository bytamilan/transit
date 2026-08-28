# Shared Dart Domain, Runtime Theme, and Map Providers

## Goal

Complete the Dart package layer so both Flutter apps share validated transit
domain types, load white-label branding at runtime, and select maps through a
provider boundary with MapLibre/OSM/Protomaps as the default and no hard
dependency on `google_maps_flutter`.

## Context and root cause

`packages/transit_core` currently contains only a README. `transit_design` and
`transit_maps` contain minimal scaffolds, while the apps use generated API
models and app-local JSON models directly. The rider app always constructs
`MapLibreProvider`, and the driver app does not apply agency branding. This
leaves the shared package boundary, runtime configuration flow, and provider
selection incomplete.

## Architecture

The generated `transit_api_client` remains the transport layer. It continues to
own OpenAPI-generated `built_value` models and serializers. A small, hand-owned
adapter layer in that package maps generated models into immutable
`transit_core` domain types. Generated files are not edited.

`transit_core` is pure Dart and has no Flutter, Dio, or map SDK dependencies.
It owns domain validation and failure types. `transit_design` depends on
`transit_core` and Flutter for runtime agency theming. `transit_maps` depends on
`transit_core` and Flutter, with MapLibre as its only default map SDK.

The dependency direction is:

```text
OpenAPI transport models -> transit_api_client adapters -> transit_core
                                                        -> transit_design
                                                        -> transit_maps
```

## Shared domain API

`transit_core` will expose the following public types from
`lib/transit_core.dart`:

### Value objects

- `GtfsId`: non-empty, trimmed GTFS identifier with value equality.
- `LocalizedText`: immutable locale-to-string values with deterministic locale
  selection: requested locale, `en`, then the first sorted available locale.
- `GtfsTime`: strict non-negative `HH:MM:SS` parsing, allowing hours greater
  than 23, with `Duration` conversion and canonical string formatting.
- `GeoPoint`: latitude and longitude with inclusive WGS84 range validation.

### Entities and configuration

- `Agency`: id, slug, localized name, and IANA timezone.
- `AgencyConfig`: locales, ISO currency, distance unit, modes, map provider,
  license, branding, and driver operations settings.
- `AgencyBranding`, `AgencyLicense`, and `DriverOpsConfig`.
- `Stop`, `Route`, `Trip`, and `StopTime` with GTFS-native field names and
  value objects where the API supplies coordinates or times.
- `DistanceUnit` and `MapProviderKind` enums. Unknown provider input resolves
  to the safe MapLibre default at the configuration boundary.

Required fields and invariants are enforced by constructors/factories. Optional
GTFS fields remain nullable. Domain construction failures use typed failures.

### Failures

`Failure` is a sealed immutable hierarchy with a stable message and optional
cause/context. It includes `NetworkFailure`, `AuthenticationFailure`,
`NotFoundFailure`, `ServerFailure`, `ParsingFailure`, `ValidationFailure`,
`CacheFailure`, and `UnknownFailure`. `TransitException` wraps a `Failure` for
imperative APIs that cannot return a result object.

The core package does not know about Dio. The API layer translates transport
exceptions, and the adapter layer translates malformed payloads, into these
types without leaking generated or HTTP implementation details to screens.

## API-client adapters

`transit_api_client` will depend on the local `transit_core` package and expose
non-generated extensions/functions such as:

```dart
Agency toDomain();
AgencyConfig toDomain();
Stop toDomain();
Route toDomain();
Trip toDomain();
StopTime toDomain();
```

The adapters convert built collections to immutable core collections, convert
GTFS strings to `GtfsTime`, and validate coordinates before constructing
entities. The generated `AgencyConfig` enum values are mapped explicitly to
core enums. Adapter tests use generated builders as fixtures and cover invalid
input.

## Runtime theming

`transit_design` will add `AgencyTheme.fromConfig(AgencyConfig)` while keeping
the existing JSON constructor for compatibility. Color parsing accepts `#RRGGBB`
and `#AARRGGBB`; malformed or missing optional branding falls back to safe
defaults instead of throwing during app startup. Theme construction uses the
agency primary/secondary colors and optional font.

The inherited theme scope compares all branding fields (including logo and
font), so runtime config changes notify dependants. Both apps use the same
scope and `ThemeData` construction. No agency-specific colors, logos, or fonts
are compiled into either app.

## Map-provider abstraction

`transit_maps` will expose immutable `MapViewOptions`, `MapMarker`,
`MapPolyline`, and `MapPoint` values through `MapProvider`. The provider API
will support initial camera state, markers, polylines, and map taps.

`MapLibreProvider` remains the default implementation and will forward marker,
polyline, and tap configuration to MapLibre. `MapProviderResolver` resolves
`MapProviderKind.maplibre` and `MapProviderKind.protomaps` to MapLibre-backed
providers. A caller may register a platform-specific provider for
`MapProviderKind.google`; when none is registered, resolution safely falls back
to MapLibre. The package will not import or depend on
`google_maps_flutter`.

The current style URL remains configurable. Protomaps is represented by a
MapLibre style configuration, keeping tile-hosting choices outside the package
and avoiding a rebuild for agency branding.

## App integration

The rider app will use domain-mapped agency config for its theme and resolve the
map provider from that config rather than constructing MapLibre directly. Its
existing test injection seam remains available.

The driver app's agency response will be mapped into the same shared agency,
config, branding, and driver-operations types. Its light/dark themes will use
the runtime agency theme while preserving the scheduled night-palette behavior.

App state and provider error paths will retain typed failures. Existing local
models that duplicate shared agency/config or GTFS stop/time data will be
removed or reduced to app-only presentation types where necessary.

## Testing and verification

- `transit_core`: value-object parsing, bounds, fallback selection, equality,
  entity invariants, and failure identity.
- `transit_api_client`: generated-model-to-domain mapping and malformed input.
- `transit_design`: color parsing, config conversion, theme values, and
  inherited-widget notifications.
- `transit_maps`: resolver selection/fallback, immutable map inputs, and
  provider forwarding behavior.
- Apps: focused runtime config/provider tests plus all existing golden tests.
- Run `dart analyze`/`flutter analyze` and package tests for every affected
  package and app. Verify the dependency graph contains no
  `google_maps_flutter` entry.

## Non-goals

- Replacing or hand-editing OpenAPI-generated files.
- Adding a Google Maps SDK or implementing a Google platform adapter in this
  change.
- Adding server-side configuration fields not present in the current contract.
- Rebuilding app navigation, planner behavior, or telemetry algorithms.
