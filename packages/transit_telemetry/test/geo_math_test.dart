import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

void main() {
  group('haversineMeters', () {
    test('same point is zero distance', () {
      expect(haversineMeters(1.3, 103.8, 1.3, 103.8), closeTo(0, 0.001));
    });

    test('one degree of latitude is about 111km', () {
      final d = haversineMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 500));
    });
  });

  group('projectOntoSegment', () {
    test('projects onto the middle of a segment', () {
      // A short east-west segment; the point is directly "above" the midpoint.
      final result = projectOntoSegment(1.001, 103.5, 1.0, 103.0, 1.0, 104.0);
      expect(result.t, closeTo(0.5, 0.05));
      expect(result.distanceM, greaterThan(0));
    });

    test('clamps to the segment start when the point projects before it', () {
      final result = projectOntoSegment(1.0, 102.0, 1.0, 103.0, 1.0, 104.0);
      expect(result.t, equals(0.0));
    });

    test('clamps to the segment end when the point projects past it', () {
      final result = projectOntoSegment(1.0, 105.0, 1.0, 103.0, 1.0, 104.0);
      expect(result.t, equals(1.0));
    });
  });
}
