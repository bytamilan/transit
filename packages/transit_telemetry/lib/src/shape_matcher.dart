import 'geo_math.dart';
import 'models.dart';

/// The result of matching one fix against a trip's shape.
class ShapeMatch {
  const ShapeMatch({required this.lat, required this.lon, required this.distTraveled, required this.perpendicularDistanceM});

  /// The fix's position snapped onto the shape polyline.
  final double lat;
  final double lon;

  /// Monotonic distance travelled along the shape, in metres — this is what
  /// stops a false arrival being registered from a parallel road or an
  /// opposite-direction stop across the street (brief §4.2 "Progression
  /// along the route").
  final double distTraveled;

  /// How far the raw fix was from the shape — large values suggest the
  /// vehicle is off-route.
  final double perpendicularDistanceM;
}

/// Projects fixes onto a trip's shape and tracks `shape_dist_traveled`
/// monotonically. A single instance is scoped to one trip; call [reset] (or
/// construct a new one) when the trip changes.
class ShapeMatcher {
  ShapeMatcher(this.shape) : assert(shape.length >= 2, 'a shape needs at least two points to match against');

  final List<ShapePoint> shape;

  double _maxDistTraveled = 0;
  bool _hasMatch = false;

  /// Fills in `distTraveled` for a raw list of (lat, lon) shape points that
  /// didn't carry GTFS `shape_dist_traveled` — cumulative haversine distance
  /// between consecutive points.
  static List<ShapePoint> fromPoints(List<({double lat, double lon})> points) {
    var cumulative = 0.0;
    final out = <ShapePoint>[];
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        cumulative += haversineMeters(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon);
      }
      out.add(ShapePoint(lat: points[i].lat, lon: points[i].lon, distTraveled: cumulative));
    }
    return out;
  }

  /// Matches [lat]/[lon] against the shape. Searches every segment (a GTFS
  /// shape is at most a few hundred points, so this is cheap) and keeps the
  /// closest one, then clamps the resulting distance so it never regresses
  /// below the furthest point already reached — a momentary bad fix or a
  /// brief backward roll at a stop must never un-arrive a stop already
  /// passed.
  ShapeMatch match(double lat, double lon) {
    var best = projectOntoSegment(lat, lon, shape[0].lat, shape[0].lon, shape[1].lat, shape[1].lon);
    var bestDistTraveled =
        shape[0].distTraveled + best.t * (shape[1].distTraveled - shape[0].distTraveled);

    for (var i = 1; i < shape.length - 1; i++) {
      final a = shape[i];
      final b = shape[i + 1];
      final projection = projectOntoSegment(lat, lon, a.lat, a.lon, b.lat, b.lon);
      if (projection.distanceM < best.distanceM) {
        best = projection;
        bestDistTraveled = a.distTraveled + projection.t * (b.distTraveled - a.distTraveled);
      }
    }

    final monotonicDist = _hasMatch ? (bestDistTraveled < _maxDistTraveled ? _maxDistTraveled : bestDistTraveled) : bestDistTraveled;
    _maxDistTraveled = monotonicDist;
    _hasMatch = true;

    return ShapeMatch(lat: best.lat, lon: best.lon, distTraveled: monotonicDist, perpendicularDistanceM: best.distanceM);
  }

  /// Resets monotonic progress — call when starting a new trip on this shape.
  void reset() {
    _maxDistTraveled = 0;
    _hasMatch = false;
  }
}
