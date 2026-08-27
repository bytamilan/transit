import 'package:test/test.dart';
import 'package:transit_telemetry/transit_telemetry.dart';

void main() {
  final shape = ShapeMatcher.fromPoints([
    (lat: 1.000, lon: 103.8),
    (lat: 1.001, lon: 103.8),
    (lat: 1.002, lon: 103.8),
  ]);
  final stops = [
    const TripStop(stopId: 'origin', sequence: 1, lat: 1.000, lon: 103.8, geofenceRadiusM: 40),
    const TripStop(stopId: 'midtown', sequence: 2, lat: 1.001, lon: 103.8, geofenceRadiusM: 40),
    const TripStop(stopId: 'terminus', sequence: 3, lat: 1.002, lon: 103.8, geofenceRadiusM: 40),
  ];
  final scheduledDeparture = DateTime(2026, 1, 5, 6, 0, 0);

  TripTracker newTracker() => TripTracker(
        stops: stops,
        shape: shape,
        scheduledDeparture: scheduledDeparture,
        dwellThreshold: const Duration(seconds: 8),
      );

  group('TripTracker auto-start', () {
    test('does not start outside the departure window even if at the origin', () {
      final tracker = newTracker();
      final events = tracker.onFix(lat: 1.000, lon: 103.8, at: scheduledDeparture.add(const Duration(hours: 2)));
      expect(tracker.phase, TripPhase.notStarted);
      expect(events, isEmpty);
    });

    test('does not start away from the origin even within the window', () {
      final tracker = newTracker();
      final events = tracker.onFix(lat: 1.002, lon: 103.8, at: scheduledDeparture);
      expect(tracker.phase, TripPhase.notStarted);
      expect(events, isEmpty);
    });

    test('starts at the origin within the departure window, early or late', () {
      final early = newTracker();
      early.onFix(lat: 1.000, lon: 103.8, at: scheduledDeparture.subtract(const Duration(minutes: 5)));
      expect(early.phase, TripPhase.inProgress);

      final late = newTracker();
      late.onFix(lat: 1.000, lon: 103.8, at: scheduledDeparture.add(const Duration(minutes: 5)));
      expect(late.phase, TripPhase.inProgress);
    });
  });

  group('TripTracker progression', () {
    test('walks origin -> midtown -> terminus and auto-ends on terminus dwell', () {
      final tracker = newTracker();
      var t = scheduledDeparture;

      // Arrive and dwell at the origin.
      var events = tracker.onFix(lat: 1.000, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.incomingAt]);

      t = t.add(const Duration(seconds: 9));
      events = tracker.onFix(lat: 1.000, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.stoppedAt]);
      expect(events.single.stopId, 'origin');

      // Depart toward midtown.
      t = t.add(const Duration(seconds: 20));
      events = tracker.onFix(lat: 1.0005, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.inTransitTo]);
      expect(events.single.stopId, 'midtown');

      // Arrive and dwell at midtown.
      t = t.add(const Duration(seconds: 20));
      events = tracker.onFix(lat: 1.001, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.incomingAt]);

      t = t.add(const Duration(seconds: 10));
      events = tracker.onFix(lat: 1.001, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.stoppedAt]);
      expect(tracker.phase, TripPhase.inProgress);

      // Depart toward the terminus.
      t = t.add(const Duration(seconds: 15));
      events = tracker.onFix(lat: 1.0015, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.inTransitTo]);
      expect(events.single.stopId, 'terminus');

      // Arrive at the terminus.
      t = t.add(const Duration(seconds: 20));
      events = tracker.onFix(lat: 1.002, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.incomingAt]);
      expect(tracker.phase, TripPhase.inProgress);

      // Dwelling at the terminus auto-ends the trip.
      t = t.add(const Duration(seconds: 10));
      events = tracker.onFix(lat: 1.002, lon: 103.8, at: t);
      expect(events.map((e) => e.status), [VehicleStopStatus.stoppedAt]);
      expect(tracker.phase, TripPhase.completed);
    });

    test('shape distance travelled never regresses across the whole trip', () {
      final tracker = newTracker();
      var t = scheduledDeparture;
      tracker.onFix(lat: 1.000, lon: 103.8, at: t);
      t = t.add(const Duration(seconds: 30));
      tracker.onFix(lat: 1.0009, lon: 103.8, at: t);
      final forward = tracker.lastMatchedDistTraveled!;

      // A noisy fix that would project slightly behind where we already are.
      t = t.add(const Duration(seconds: 5));
      tracker.onFix(lat: 1.0008, lon: 103.8, at: t);
      expect(tracker.lastMatchedDistTraveled, greaterThanOrEqualTo(forward));
    });

    test('ignores fixes once the trip has completed', () {
      final tracker = newTracker();
      tracker.endManually();
      final events = tracker.onFix(lat: 1.002, lon: 103.8, at: scheduledDeparture.add(const Duration(minutes: 30)));
      expect(events, isEmpty);
      expect(tracker.phase, TripPhase.completed);
    });
  });
}
