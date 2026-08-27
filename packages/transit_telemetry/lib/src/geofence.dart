import 'geo_math.dart';

/// True when (lat, lon) is within radiusM of (centerLat, centerLon).
bool withinGeofence({
  required double lat,
  required double lon,
  required double centerLat,
  required double centerLon,
  required double radiusM,
}) {
  return haversineMeters(lat, lon, centerLat, centerLon) <= radiusM;
}
