import 'dart:math' as math;

/// Earth radius in metres (mean radius, WGS-84 approximation) — good enough
/// for stop-geofence and shape-matching distances, which are always small
/// relative to the curvature.
const double earthRadiusM = 6371000.0;

/// Great-circle distance between two lat/lon points, in metres.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _deg2rad(lat1);
  final phi2 = _deg2rad(lat2);
  final dPhi = _deg2rad(lat2 - lat1);
  final dLambda = _deg2rad(lon2 - lon1);

  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

double _deg2rad(double deg) => deg * math.pi / 180.0;

/// The result of projecting a point onto a line segment: the projected
/// point, the distance from the original point to the projection, and `t` in
/// [0, 1] locating the projection along the segment (0 = segment start, 1 =
/// segment end). Uses an equirectangular approximation local to the segment,
/// which is accurate enough for the metre-scale segment lengths in a GTFS
/// shape (a few hundred metres between shape points, at most).
class SegmentProjection {
  const SegmentProjection({required this.lat, required this.lon, required this.distanceM, required this.t});

  final double lat;
  final double lon;
  final double distanceM;
  final double t;
}

SegmentProjection projectOntoSegment(
  double pLat,
  double pLon,
  double aLat,
  double aLon,
  double bLat,
  double bLon,
) {
  // Local equirectangular projection centred on segment start — cheap and
  // accurate at the scale of adjacent GTFS shape points.
  final cosLat = math.cos(_deg2rad(aLat));
  double toX(double lon) => _deg2rad(lon - aLon) * cosLat * earthRadiusM;
  double toY(double lat) => _deg2rad(lat - aLat) * earthRadiusM;

  final ax = 0.0, ay = 0.0;
  final bx = toX(bLon), by = toY(bLat);
  final px = toX(pLon), py = toY(pLat);

  final abx = bx - ax, aby = by - ay;
  final lenSq = abx * abx + aby * aby;
  double t = lenSq == 0 ? 0 : ((px - ax) * abx + (py - ay) * aby) / lenSq;
  t = t.clamp(0.0, 1.0);

  final projX = ax + t * abx;
  final projY = ay + t * aby;
  final dx = px - projX, dy = py - projY;
  final distanceM = math.sqrt(dx * dx + dy * dy);

  // Convert the projected local point back to lat/lon.
  final lat = aLat + (projY / earthRadiusM) * 180.0 / math.pi;
  final lon = aLon + (projX / (earthRadiusM * cosLat)) * 180.0 / math.pi;

  return SegmentProjection(lat: lat, lon: lon, distanceM: distanceM, t: t);
}
