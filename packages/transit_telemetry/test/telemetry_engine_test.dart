import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

void main() {
  group('TelemetryEngine', () {
    late TelemetryEngine engine;
    late PingQueue queue;

    setUp(() {
      queue = PingQueue(storage: InMemoryPingStorage());
      engine = TelemetryEngine(
        assignmentId: 'assignment-1',
        sampler: AdaptiveSampler(movingIntervalSeconds: 5, idleIntervalSeconds: 60),
        queue: queue,
      );
    });

    test('drops a junk fix and enqueues nothing', () async {
      final events = await engine.onRawFix(
        GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6), accuracyM: 500),
      );
      expect(events, isEmpty);
      expect(await queue.length, 0);
    });

    test('enqueues the first good fix immediately', () async {
      await engine.onRawFix(GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 0), speedMps: 8));
      expect(await queue.length, 1);
    });

    test('throttles subsequent fixes to the sampler interval', () async {
      await engine.onRawFix(GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 0), speedMps: 8));
      // One second later — well under the 5-second moving interval.
      await engine.onRawFix(GeoFix(lat: 1.30001, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 1), speedMps: 8));
      expect(await queue.length, 1);

      // Six seconds after the first — past the interval, should enqueue.
      await engine.onRawFix(GeoFix(lat: 1.30002, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 6), speedMps: 8));
      expect(await queue.length, 2);
    });

    test('flush uploads and acknowledges only on success', () async {
      await engine.onRawFix(GeoFix(lat: 1.3, lon: 103.8, timestamp: DateTime(2026, 1, 1, 6, 0, 0)));

      final failedOk = await engine.flush((batch) async => false);
      expect(failedOk, isFalse);
      expect(await queue.length, 1);

      final succeededOk = await engine.flush((batch) async => true);
      expect(succeededOk, isTrue);
      expect(await queue.length, 0);
    });

    test('reports stop events once a trip is tracked', () async {
      final shape = ShapeMatcher.fromPoints([
        (lat: 1.000, lon: 103.8),
        (lat: 1.001, lon: 103.8),
      ]);
      final stops = [
        const TripStop(stopId: 'origin', sequence: 1, lat: 1.000, lon: 103.8, geofenceRadiusM: 40),
        const TripStop(stopId: 'terminus', sequence: 2, lat: 1.001, lon: 103.8, geofenceRadiusM: 40),
      ];
      final scheduledDeparture = DateTime(2026, 1, 5, 6, 0, 0);
      engine.startTrip(TripTracker(stops: stops, shape: shape, scheduledDeparture: scheduledDeparture));

      final events = await engine.onRawFix(GeoFix(lat: 1.000, lon: 103.8, timestamp: scheduledDeparture));
      expect(events.map((e) => e.status), [VehicleStopStatus.incomingAt]);
    });
  });
}
