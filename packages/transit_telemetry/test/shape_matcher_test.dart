import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

void main() {
  // A straight north-south shape so distances are easy to reason about.
  final shape = ShapeMatcher.fromPoints([
    (lat: 1.000, lon: 103.8),
    (lat: 1.001, lon: 103.8),
    (lat: 1.002, lon: 103.8),
  ]);
  final segmentLengthM = shape[1].distTraveled; // ~111m per 0.001 degree of latitude

  group('ShapeMatcher', () {
    test('matches a point on the shape near its true distance travelled', () {
      final matcher = ShapeMatcher(shape);
      final match = matcher.match(1.0005, 103.8); // roughly midway along the first segment
      expect(match.distTraveled, closeTo(segmentLengthM / 2, segmentLengthM * 0.1));
      expect(match.perpendicularDistanceM, lessThan(1.0));
    });

    test('reports a large perpendicular distance for an off-route point', () {
      final matcher = ShapeMatcher(shape);
      final match = matcher.match(1.0005, 103.9); // far to the east of the shape
      expect(match.perpendicularDistanceM, greaterThan(1000));
    });

    test('distance travelled never regresses even if a later fix matches earlier on the shape', () {
      final matcher = ShapeMatcher(shape);
      final forward = matcher.match(1.0015, 103.8); // near the second segment
      final noisyBackward = matcher.match(1.0002, 103.8); // GPS noise pulling back toward the start

      expect(noisyBackward.distTraveled, greaterThanOrEqualTo(forward.distTraveled));
    });

    test('reset allows distance to start over for a new trip', () {
      final matcher = ShapeMatcher(shape);
      matcher.match(1.0015, 103.8);
      matcher.reset();

      final afterReset = matcher.match(1.0001, 103.8);
      expect(afterReset.distTraveled, lessThan(segmentLengthM));
    });
  });
}
