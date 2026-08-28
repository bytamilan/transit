import 'package:flutter/widgets.dart';
import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_maps/transit_maps.dart';

void main() {
  group('MapProviderResolver', () {
    test('returns each registered provider for its matching kind', () {
      final mapLibre = _FakeMapProvider();
      final protomaps = _FakeMapProvider();
      final google = _FakeMapProvider();
      final resolver = MapProviderResolver(
        mapLibre: mapLibre,
        protomaps: protomaps,
        google: google,
      );

      expect(resolver.resolve(MapProviderKind.maplibre), same(mapLibre));
      expect(resolver.resolve(MapProviderKind.protomaps), same(protomaps));
      expect(resolver.resolve(MapProviderKind.google), same(google));
    });

    test('falls back to MapLibre when Google is not registered', () {
      final mapLibre = _FakeMapProvider();
      final resolver = MapProviderResolver(mapLibre: mapLibre);

      expect(resolver.resolve(MapProviderKind.google), same(mapLibre));
    });
  });
}

class _FakeMapProvider implements MapProvider {
  @override
  Widget buildMap(MapViewOptions options) => const SizedBox.shrink();
}
