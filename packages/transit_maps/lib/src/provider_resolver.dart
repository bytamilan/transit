import 'package:transit_core/transit_core.dart';

import 'map_provider.dart';

class MapProviderResolver {
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
