# transit_core (Dart)

Entities, GTFS value objects, and failures shared by both Flutter apps
(`rider_app`, `driver_app`) and `transit_design`/`transit_maps`. Pure Dart —
no Flutter dependency — so domain logic is testable without a device and
reusable outside the UI layer.

Every type here is immutable, validates on construction (or via
`.fromJson`), and implements structural `==`/`hashCode`. There's no
network or storage code in this package — it's the shared vocabulary the
API client, the apps, and the design/maps packages build on.

## Exports (`lib/transit_core.dart`)

**Entities**

- `Agency` — `id`, `slug`, `name` (`LocalizedText`), `timezone`.
- `AgencyConfig` — `locales`, `currency`, `distanceUnit`, `modes`,
  `mapProvider`, `license` (`AgencyLicense`), `branding` (`AgencyBranding`),
  `driverOps` (`DriverOpsConfig`, defaults applied when omitted). The Dart
  mirror of the agency-config JSON document every agency deploys with
  (build brief §2/§10) — one document, no code changes, per agency.
- `Stop`, `Route`, `Trip`, `StopTime` — GTFS core entities. `Stop.coordinates`
  is a `GeoPoint?` (both lat/lon or neither); `StopTime.arrivalTime`/
  `departureTime` are `GtfsTime?`, not raw strings.

**Failures** (`Failure` sealed class + `TransitException`)

`NetworkFailure`, `AuthenticationFailure`, `NotFoundFailure`,
`ServerFailure`, `ParsingFailure`, `ValidationFailure`, `CacheFailure`,
`UnknownFailure` — each carries a `message`, an optional `cause`, and a
`context` map. Entity constructors and `.fromJson` factories throw
`ValidationFailure` on bad input; nothing in this package throws a raw
`Exception`/`ArgumentError`.

**Value objects**

- `GeoPoint` — validated lat/lon (`-90..90`, `-180..180`).
- `GtfsId` — a non-empty, trimmed identifier wrapper.
- `GtfsTime` — parses/formats GTFS's `HH:MM:SS` time-of-day format, where
  hours can exceed 23 for post-midnight service (see
  [ADR 0002](https://github.com/bytamilan/transit/blob/main/internal-docs/adr/0002-stop-times-after-midnight.md)
  in the source repo, or the Wiki → ADRs section of this site).
  `Comparable<GtfsTime>`, backed by a `Duration`.
- `LocalizedText` — a non-empty `Map<String, String>` of locale → text,
  with `.pick(locale)` falling back to `en`, then the alphabetically-first
  entry (matches the fallback rule used server-side for agency names and
  service alerts).

## Usage

```dart
import 'package:transit_core/transit_core.dart' as core;

final agency = core.Agency.fromJson(json['agency'] as Map<String, dynamic>);
final config = core.AgencyConfig.fromJson(json['config'] as Map<String, dynamic>);

print(agency.name.pick('ta')); // falls back to 'en', then first locale

try {
  core.GtfsTime.parse('25:30:00'); // valid — after-midnight service
} on core.ValidationFailure catch (e) {
  print(e.message);
}
```
