import 'package:flutter/material.dart';

/// Abstract map provider. The default implementation is MapLibre; other
/// providers can be swapped in behind this interface.
abstract class MapProvider {
  Widget buildMap({
    required double initialLat,
    required double initialLon,
    required double zoom,
    required List<MapMarker> markers,
    required List<MapPolyline> polylines,
    required void Function(double lat, double lon)? onTap,
  });
}

class MapMarker {
  final double lat;
  final double lon;
  final String? label;
  final Color? color;

  MapMarker({required this.lat, required this.lon, this.label, this.color});
}

class MapPolyline {
  final List<MapPoint> points;
  final Color color;
  final double width;

  MapPolyline({required this.points, required this.color, this.width = 4});
}

class MapPoint {
  final double lat;
  final double lon;

  MapPoint(this.lat, this.lon);
}
