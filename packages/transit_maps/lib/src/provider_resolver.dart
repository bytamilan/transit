import 'package:transit_core/transit_core.dart';

import 'map_provider.dart';
import 'map_view.dart';

class MapProviderResolver {
  const MapProviderResolver.defaults()
      : mapLibre = const MapLibreProvider(),
        protomaps = const ProtomapsProvider(),
        google = null;

  const MapProviderResolver({
    required this.mapLibre,
    this.protomaps,
    this.google,
  });

  final MapProvider mapLibre;
  final MapProvider? protomaps;
  final MapProvider? google;

  MapProvider resolve(MapProviderKind kind) => switch (kind) {
        MapProviderKind.maplibre => mapLibre,
        MapProviderKind.protomaps => protomaps ?? mapLibre,
        MapProviderKind.google => google ?? mapLibre,
      };
}
