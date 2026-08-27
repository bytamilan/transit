import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

void main() {
  group('AdaptiveSampler', () {
    final sampler = AdaptiveSampler(
      movingIntervalSeconds: 5,
      idleIntervalSeconds: 60,
      idleSpeedThresholdMps: 0.5,
      nearStopRadiusM: 150,
      nearStopIntervalSeconds: 2,
    );

    test('uses the moving interval above the idle threshold', () {
      expect(sampler.intervalFor(speedMps: 8.0), equals(const Duration(seconds: 5)));
    });

    test('uses the idle interval at or below the idle threshold', () {
      expect(sampler.intervalFor(speedMps: 0.1), equals(const Duration(seconds: 60)));
      expect(sampler.intervalFor(speedMps: null), equals(const Duration(seconds: 60)));
    });

    test('bursts near a stop regardless of speed', () {
      expect(sampler.intervalFor(speedMps: 8.0, distanceToNextStopM: 50), equals(const Duration(seconds: 2)));
      expect(sampler.intervalFor(speedMps: 0.0, distanceToNextStopM: 10), equals(const Duration(seconds: 2)));
    });

    test('does not burst outside the near-stop radius', () {
      expect(sampler.intervalFor(speedMps: 8.0, distanceToNextStopM: 500), equals(const Duration(seconds: 5)));
    });
  });
}
