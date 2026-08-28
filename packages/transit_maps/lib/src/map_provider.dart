import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:transit_core/transit_core.dart';

/// Abstract map provider. The default implementation is MapLibre; other
/// providers can be swapped in behind this interface.
abstract class MapProvider {
  Widget buildMap(MapViewOptions options);
}

class MapViewOptions {
  MapViewOptions({
    required this.provider,
    required this.initialLat,
    required this.initialLon,
    required this.zoom,
    List<MapMarker> markers = const [],
    List<MapPolyline> polylines = const [],
    this.onMapClick,
  })  : markers = List.unmodifiable(markers),
        polylines = List.unmodifiable(polylines);

  final MapProviderKind provider;
  final double initialLat;
  final double initialLon;
  final double zoom;
  final List<MapMarker> markers;
  final List<MapPolyline> polylines;
  final void Function(double lat, double lon)? onMapClick;

  MapViewOptions copyWith({
    MapProviderKind? provider,
    double? initialLat,
    double? initialLon,
    double? zoom,
    List<MapMarker>? markers,
    List<MapPolyline>? polylines,
    void Function(double lat, double lon)? onMapClick,
  }) =>
      MapViewOptions(
        provider: provider ?? this.provider,
        initialLat: initialLat ?? this.initialLat,
        initialLon: initialLon ?? this.initialLon,
        zoom: zoom ?? this.zoom,
        markers: markers ?? this.markers,
        polylines: polylines ?? this.polylines,
        onMapClick: onMapClick ?? this.onMapClick,
      );

  @override
  bool operator ==(Object other) =>
      other is MapViewOptions &&
      provider == other.provider &&
      initialLat == other.initialLat &&
      initialLon == other.initialLon &&
      zoom == other.zoom &&
      listEquals(markers, other.markers) &&
      listEquals(polylines, other.polylines) &&
      onMapClick == other.onMapClick;

  @override
  int get hashCode => Object.hash(
        provider,
        initialLat,
        initialLon,
        zoom,
        Object.hashAll(markers),
        Object.hashAll(polylines),
        onMapClick,
      );
}

class MapMarker {
  final double lat;
  final double lon;
  final String? label;
  final Color? color;

  const MapMarker(
      {required this.lat, required this.lon, this.label, this.color});

  MapMarker copyWith({double? lat, double? lon, String? label, Color? color}) =>
      MapMarker(
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        label: label ?? this.label,
        color: color ?? this.color,
      );

  @override
  bool operator ==(Object other) =>
      other is MapMarker &&
      lat == other.lat &&
      lon == other.lon &&
      label == other.label &&
      color == other.color;

  @override
  int get hashCode => Object.hash(lat, lon, label, color);
}

class MapPolyline {
  final List<MapPoint> points;
  final Color color;
  final double width;

  MapPolyline(
      {required List<MapPoint> points, required this.color, this.width = 4})
      : points = List.unmodifiable(points);

  MapPolyline copyWith({List<MapPoint>? points, Color? color, double? width}) =>
      MapPolyline(
        points: points ?? this.points,
        color: color ?? this.color,
        width: width ?? this.width,
      );

  @override
  bool operator ==(Object other) =>
      other is MapPolyline &&
      listEquals(points, other.points) &&
      color == other.color &&
      width == other.width;

  @override
  int get hashCode => Object.hash(Object.hashAll(points), color, width);
}

class MapPoint {
  final double lat;
  final double lon;

  const MapPoint(this.lat, this.lon);

  @override
  bool operator ==(Object other) =>
      other is MapPoint && lat == other.lat && lon == other.lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}
