import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

void main() {
  group('GeoKalmanFilter', () {
    test('first fix passes through unchanged', () {
      final f = GeoKalmanFilter();
      final result = f.update(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 0), accuracyM: 10);
      expect(result.lat, equals(1.3));
      expect(result.lon, equals(103.8));
    });

    test('smooths a noisy fix toward the running estimate rather than jumping to it', () {
      final f = GeoKalmanFilter();
      f.update(lat: 1.3000, lon: 103.8000, timestamp: DateTime(2026, 1, 1, 6, 0, 0), accuracyM: 5);

      // A single wildly noisy fix one second later should be pulled toward
      // the prior estimate, not fully trusted.
      final noisy = f.update(lat: 1.3010, lon: 103.8010, timestamp: DateTime(2026, 1, 1, 6, 0, 1), accuracyM: 50);

      expect(noisy.lat, greaterThan(1.3000));
      expect(noisy.lat, lessThan(1.3010));
    });

    test('converges toward a sequence of consistent fixes', () {
      final f = GeoKalmanFilter();
      var result = (lat: 1.0, lon: 103.0);
      final start = DateTime(2026, 1, 1, 6, 0, 0);
      for (var i = 0; i < 20; i++) {
        result = f.update(lat: 1.3000, lon: 103.8000, timestamp: start.add(Duration(seconds: i)), accuracyM: 10);
      }
      expect(result.lat, closeTo(1.3000, 0.0005));
      expect(result.lon, closeTo(103.8000, 0.0005));
    });

    test('reset discards prior state so the next fix passes through unchanged', () {
      final f = GeoKalmanFilter();
      f.update(lat: 1.0, lon: 103.0, timestamp: DateTime(2026, 1, 1, 6, 0, 0), accuracyM: 5);
      f.reset();

      final result = f.update(lat: 2.0, lon: 104.0, timestamp: DateTime(2026, 1, 1, 7, 0, 0), accuracyM: 5);
      expect(result.lat, equals(2.0));
      expect(result.lon, equals(104.0));
    });
  });
}
