import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

void main() {
  group('FixValidator', () {
    test('accepts a good fix', () {
      final v = FixValidator();
      final fix = GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6), accuracyM: 10, speedMps: 8);
      expect(v.accept(fix), same(fix));
    });

    test('rejects a fix with poor accuracy', () {
      final v = FixValidator(maxAccuracyM: 50);
      final fix = GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6), accuracyM: 200);
      expect(v.accept(fix), isNull);
    });

    test('rejects a fix with an implausible reported speed', () {
      final v = FixValidator(maxPlausibleSpeedMps: 55);
      final fix = GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6), speedMps: 300);
      expect(v.accept(fix), isNull);
    });

    test('rejects a teleport jump implied by distance over time', () {
      final v = FixValidator(maxTeleportSpeedMps: 70);
      final first = GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 0));
      final teleported = GeoFix(lat: 1.5, lon: 104.0, timestamp: DateTime(2026, 1, 1, 6, 0, 5));

      expect(v.accept(first), same(first));
      expect(v.accept(teleported), isNull);
    });

    test('accepts continuous plausible movement', () {
      final v = FixValidator();
      final first = GeoFix(lat: 1.3000, lon: 103.8000, timestamp: DateTime(2026, 1, 1, 6, 0, 0));
      final next = GeoFix(lat: 1.30009, lon: 103.80009, timestamp: DateTime(2026, 1, 1, 6, 0, 5));

      expect(v.accept(first), isNotNull);
      expect(v.accept(next), isNotNull);
    });

    test('rejects an out-of-order fix', () {
      final v = FixValidator();
      final first = GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 5));
      final earlier = GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 0));

      expect(v.accept(first), isNotNull);
      expect(v.accept(earlier), isNull);
    });

    test('reset clears teleport-detection state', () {
      final v = FixValidator(maxTeleportSpeedMps: 70);
      final first = GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 0));
      expect(v.accept(first), isNotNull);

      v.reset();

      final farAway = GeoFix(lat: -1.0, lon: 36.0, timestamp: DateTime(2026, 1, 1, 6, 0, 1));
      expect(v.accept(farAway), isNotNull);
    });
  });
}
