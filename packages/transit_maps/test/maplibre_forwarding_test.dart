import 'package:flutter/material.dart';
import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_maps/transit_maps.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  test('forwards markers and polylines to the MapLibre sink', () async {
    final sink = _RecordingSink();
    final options = MapViewOptions(
      provider: MapProviderKind.maplibre,
      initialLat: 1,
      initialLon: 2,
      zoom: 12,
      markers: const [MapMarker(lat: 3, lon: 4, label: 'Stop')],
      polylines: [
        MapPolyline(
          points: const [MapPoint(5, 6), MapPoint(7, 8)],
          color: Colors.blue,
        ),
      ],
    );

    await MapLibreAnnotationForwarder().forward(sink, options);

    expect(sink.markers, options.markers);
    expect(sink.polylines, options.polylines);
  });

  test('forwards MapLibre clicks to the neutral callback', () {
    double? latitude;
    double? longitude;
    final options = MapViewOptions(
      provider: MapProviderKind.maplibre,
      initialLat: 1,
      initialLon: 2,
      zoom: 12,
      onMapClick: (lat, lon) {
        latitude = lat;
        longitude = lon;
      },
    );

    forwardMapClick(options, LatLng(9, 10));

    expect(latitude, 9);
    expect(longitude, 10);
  });

  test('uses a distinct Protomaps provider and production style', () {
    const resolver = MapProviderResolver.defaults();
    final provider = resolver.resolve(MapProviderKind.protomaps);

    expect(provider, isA<ProtomapsProvider>());
    expect((provider as ProtomapsProvider).styleUrl,
        'https://api.protomaps.com/styles/v2/light.json');
  });
}

class _RecordingSink implements MapLibreAnnotationSink {
  final markers = <MapMarker>[];
  final polylines = <MapPolyline>[];

  @override
  Future<void> addMarker(MapMarker marker) async => markers.add(marker);

  @override
  Future<void> addPolyline(MapPolyline polyline) async =>
      polylines.add(polyline);
}
