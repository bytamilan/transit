import 'adaptive_sampler.dart';
import 'fix_validator.dart';
import 'kalman_filter.dart';
import 'models.dart';
import 'ping_queue.dart';
import 'trip_tracker.dart';

/// Wires validation, smoothing, adaptive sampling, trip/stop tracking and
/// the persistent queue together into the single entry point the driver app
/// calls on every raw location update. One engine instance is scoped to one
/// open duty (one `assignmentId`); construct a new one per duty.
class TelemetryEngine {
  TelemetryEngine({
    required this.assignmentId,
    required this.sampler,
    required this.queue,
    FixValidator? validator,
    GeoKalmanFilter? filter,
  })  : validator = validator ?? FixValidator(),
        filter = filter ?? GeoKalmanFilter();

  final String assignmentId;
  final FixValidator validator;
  final GeoKalmanFilter filter;
  final AdaptiveSampler sampler;
  final PingQueue queue;

  TripTracker? _tripTracker;
  DateTime? _lastEmittedPingAt;
  int? _occupancy;

  /// Starts (or replaces) trip tracking against a specific shape/stop
  /// sequence. Call this once the app knows which trip the driver is on
  /// (from `duty_assignments` → the block's trips).
  void startTrip(TripTracker tracker) {
    _tripTracker = tracker;
    validator.reset();
    _lastEmittedPingAt = null;
  }

  /// The driver's current one-tap occupancy selection, applied to every
  /// ping until changed. Only meaningful while stopped — the app should
  /// enforce that at the UI layer (brief §4: "permitted only when stopped").
  void setOccupancy(OccupancyStatus status) {
    _occupancy = status.value;
  }

  /// Feeds one raw fix through the full pipeline. Returns the stop events
  /// produced (if a trip is being tracked) — empty when the fix was
  /// rejected as junk, throttled by the adaptive sampler, or no trip is
  /// active yet.
  Future<List<StopEvent>> onRawFix(GeoFix rawFix) async {
    final accepted = validator.accept(rawFix);
    if (accepted == null) {
      return const [];
    }

    final smoothed = filter.update(
      lat: accepted.lat,
      lon: accepted.lon,
      timestamp: accepted.timestamp,
      accuracyM: accepted.accuracyM,
    );

    final tracker = _tripTracker;
    var events = const <StopEvent>[];
    if (tracker != null) {
      events = tracker.onFix(lat: smoothed.lat, lon: smoothed.lon, at: accepted.timestamp, speedMps: accepted.speedMps);
    }
    final matchedDist = tracker?.lastMatchedDistTraveled;
    final distanceToNextStop = _distanceToNextStop(tracker);

    if (!_shouldEmit(accepted.timestamp, accepted.speedMps, distanceToNextStop)) {
      return events;
    }

    _lastEmittedPingAt = accepted.timestamp;
    await queue.enqueue(PingRecord(
      assignmentId: assignmentId,
      ts: accepted.timestamp,
      lat: smoothed.lat,
      lon: smoothed.lon,
      heading: accepted.headingDeg,
      speed: accepted.speedMps,
      accuracyM: accepted.accuracyM,
      occupancy: _occupancy,
      matchedShapeDist: matchedDist,
    ));

    return events;
  }

  bool _shouldEmit(DateTime at, double? speedMps, double? distanceToNextStopM) {
    final last = _lastEmittedPingAt;
    if (last == null) return true;
    final interval = sampler.intervalFor(speedMps: speedMps, distanceToNextStopM: distanceToNextStopM);
    return at.difference(last) >= interval;
  }

  double? _distanceToNextStop(TripTracker? tracker) {
    if (tracker == null) return null;
    final target = tracker.currentStopDistTraveled;
    final matched = tracker.lastMatchedDistTraveled;
    if (target == null || matched == null) return null;
    final remaining = target - matched;
    return remaining < 0 ? 0 : remaining;
  }

  /// Attempts to flush one batch from the queue via [upload]. [upload]
  /// should return true only once the server has durably accepted the
  /// batch — the queue is only advanced on success, so a failed or
  /// interrupted upload (e.g. the 40-minute airplane-mode gap in the Phase 7
  /// gate) leaves everything queued for the next attempt.
  Future<bool> flush(Future<bool> Function(List<PingRecord> batch) upload) async {
    final batch = await queue.nextBatch();
    if (batch.isEmpty) return true;
    final ok = await upload(batch);
    if (ok) {
      await queue.acknowledge(batch);
    }
    return ok;
  }
}
