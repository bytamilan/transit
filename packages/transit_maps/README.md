# transit_maps (Dart)

Map provider abstraction. MapLibre + OSM/Protomaps is the default; Google is
optional, and the apps never hard-depend on `google_maps_flutter` (build
brief §7) — swapping providers is a config choice (`AgencyConfig.mapProvider`),
not a code change.

## Exports (`lib/transit_maps.dart`)

- **`MapProvider`** — the abstraction every provider implements: one method,
  `Widget buildMap(MapViewOptions options)`.
- **`MapViewOptions`** — provider-neutral map state: `provider`
  (`transit_core.MapProviderKind`), `initialLat`/`initialLon`/`zoom`,
  `markers` (`List<MapMarker>`), `polylines` (`List<MapPolyline>`), and an
  `onMapClick` callback. Immutable with a `copyWith`.
- **`MapMarker`**, **`MapPolyline`**, **`MapPoint`** — provider-neutral pin
  and route-shape primitives; nothing in this package's public API ever
  exposes a MapLibre- or Google-specific type.
- **`MapLibreProvider`** — the default `MapProvider` implementation,
  rendering `MapViewOptions` through `package:maplibre_gl`. Forwards
  markers/polylines to the map controller via the testable
  `MapLibreAnnotationSink` interface, so annotation logic can be verified
  without a real map view.
- **`ProtomapsProvider`** — a `MapLibreProvider` subclass pointed at a
  Protomaps production style instead of the MapLibre demo tiles; same
  rendering path, different `styleUrl`.
- **`MapProviderResolver`** — picks the concrete `MapProvider` for a given
  `MapProviderKind` (from the agency's config): `.resolve(MapProviderKind.protomaps)`
  falls back to MapLibre if no Protomaps provider was supplied, and
  `google` falls back to MapLibre too, since Google support is optional and
  never assumed present. `MapProviderResolver.defaults()` wires up MapLibre
  + Protomaps with no Google provider — the out-of-the-box configuration.

## Usage

```dart
import 'package:transit_maps/transit_maps.dart';
import 'package:transit_core/transit_core.dart' as core;

const resolver = MapProviderResolver.defaults();

Widget buildAgencyMap(core.AgencyConfig config, List<core.Stop> stops) {
  final provider = resolver.resolve(config.mapProvider);
  return provider.buildMap(
    MapViewOptions(
      provider: config.mapProvider,
      initialLat: 1.2966,
      initialLon: 103.7764,
      zoom: 13,
      markers: [
        for (final stop in stops)
          if (stop.coordinates case final coords?)
            MapMarker(lat: coords.latitude, lon: coords.longitude, label: stop.stopName),
      ],
    ),
  );
}
```

Screens under test substitute a fake `MapProvider` (see
`apps/rider_app/test/golden/fixtures.dart`'s `FakeMapProvider`) instead of
`MapLibreProvider`, since the real MapLibre widget is a native platform view
that doesn't render in a headless `flutter test`.
