import 'package:flutter/material.dart';
import 'package:test/test.dart';
import 'package:transit_core/transit_core.dart';
import 'package:transit_maps/transit_maps.dart';

void main() {
  test('map primitive collections cannot be mutated through their input lists',
      () {
    final markers = [const MapMarker(lat: 1, lon: 2)];
    final points = [const MapPoint(1, 2)];
    final polylines = [
      MapPolyline(points: points, color: const Color(0xFF123456)),
    ];
    final options = MapViewOptions(
      provider: MapProviderKind.maplibre,
      initialLat: 1,
      initialLon: 2,
      zoom: 3,
      markers: markers,
      polylines: polylines,
    );

    markers.add(const MapMarker(lat: 3, lon: 4));
    points.add(const MapPoint(3, 4));
    polylines.add(MapPolyline(points: const [], color: Colors.red));

    expect(options.markers, [const MapMarker(lat: 1, lon: 2)]);
    expect(options.polylines.single.points, [const MapPoint(1, 2)]);
    expect(options.polylines, hasLength(1));
    expect(
      () => options.markers.add(const MapMarker(lat: 3, lon: 4)),
      throwsUnsupportedError,
    );
    expect(
      () => options.polylines.single.points.add(const MapPoint(3, 4)),
      throwsUnsupportedError,
    );
  });

  test('map primitives use all fields for value equality', () {
    final onMapClick = (double lat, double lon) {};
    final options = MapViewOptions(
      provider: MapProviderKind.protomaps,
      initialLat: 1,
      initialLon: 2,
      zoom: 3,
      markers: const [
        MapMarker(
          lat: 4,
          lon: 5,
          label: 'Stop',
          color: Color(0xFF123456),
        ),
      ],
      polylines: [
        MapPolyline(
          points: [MapPoint(6, 7), MapPoint(8, 9)],
          color: Color(0xFF654321),
          width: 6,
        ),
      ],
      onMapClick: onMapClick,
    );

    expect(
      options,
      MapViewOptions(
        provider: MapProviderKind.protomaps,
        initialLat: 1,
        initialLon: 2,
        zoom: 3,
        markers: const [
          MapMarker(
            lat: 4,
            lon: 5,
            label: 'Stop',
            color: Color(0xFF123456),
          ),
        ],
        polylines: [
          MapPolyline(
            points: [MapPoint(6, 7), MapPoint(8, 9)],
            color: Color(0xFF654321),
            width: 6,
          ),
        ],
        onMapClick: onMapClick,
      ),
    );
    expect(options, isNot(options.copyWith(zoom: 4)));
    expect(options.markers.single,
        isNot(options.markers.single.copyWith(label: 'Other')));
    expect(options.polylines.single,
        isNot(options.polylines.single.copyWith(width: 7)));
    expect(options.polylines.single.points.first, isNot(const MapPoint(10, 7)));
  });
}
