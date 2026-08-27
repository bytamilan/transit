import 'geofence.dart';
import 'models.dart';
import 'shape_matcher.dart';

enum TripPhase { notStarted, inProgress, completed }

/// Tracks one trip's lifecycle from auto-start through stop-by-stop
/// progression to auto-end, purely from a stream of GPS fixes plus the
/// trip's own shape and stop sequence (brief §4.2). Every fix should already
/// be validated ([FixValidator]) and smoothed ([GeoKalmanFilter]) before
/// reaching this class — it trusts what it's given.
class TripTracker {
  TripTracker({
    required this.stops,
    required List<ShapePoint> shape,
    required this.scheduledDeparture,
    this.departureWindow = const Duration(minutes: 15),
    this.dwellThreshold = const Duration(seconds: 8),
    this.skipAheadToleranceM = 120.0,
  })  : assert(stops.length >= 2, 'a trip needs at least an origin and a terminus'),
        _liveMatcher = ShapeMatcher(shape),
        _stopDistTraveled = _precomputeStopDistances(stops, shape);

  final List<TripStop> stops;

  /// The trip's scheduled departure — auto-start is only considered within
  /// [departureWindow] of this instant, so an implausible early/late
  /// position never falsely starts the trip (brief: "early or late
  /// departures still match; only an implausible position ... suppresses
  /// it").
  final DateTime scheduledDeparture;
  final Duration departureWindow;

  /// How long the vehicle must stay within a stop's geofence before it's
  /// counted as actually stopped there, not just passing close by.
  final Duration dwellThreshold;

  /// How far past a stop's shape position progress must reach before the
  /// tracker gives up waiting for a geofence hit and advances anyway — a
  /// safety net for a missed fix or a stop the driver's phone lost signal
  /// near, so tracking never gets stuck on one stop forever.
  final double skipAheadToleranceM;

  final ShapeMatcher _liveMatcher;
  final List<double> _stopDistTraveled;

  TripPhase _phase = TripPhase.notStarted;
  int _currentStopIndex = 0;
  DateTime? _dwellStart;
  bool _incomingEmitted = false;
  bool _stoppedEmitted = false;

  TripPhase get phase => _phase;
  int get currentStopIndex => _currentStopIndex;

  /// The current target stop's fixed position along the shape, or null once
  /// the trip has completed. Combined with [lastMatchedDistTraveled], this is
  /// what lets the sampler know how close the vehicle is to its next stop.
  double? get currentStopDistTraveled =>
      _phase == TripPhase.completed || _currentStopIndex >= stops.length ? null : _stopDistTraveled[_currentStopIndex];

  /// The live vehicle's most recent matched distance along the shape, or
  /// null before the trip has started.
  double? get lastMatchedDistTraveled => _lastMatchedDistTraveled;
  double? _lastMatchedDistTraveled;

  static List<double> _precomputeStopDistances(List<TripStop> stops, List<ShapePoint> shape) {
    final referenceMatcher = ShapeMatcher(shape);
    // Stops are matched in order against a fresh (non-monotonic-sensitive)
    // pass — monotonic clamping only matters for the live vehicle trace, not
    // for computing each stop's fixed reference position on the shape.
    return stops.map((s) => referenceMatcher.match(s.lat, s.lon).distTraveled).toList();
  }

  /// Feeds one validated/smoothed fix through the tracker. Returns any
  /// [StopEvent]s produced (usually zero or one, occasionally two if a fix
  /// both departs one stop and immediately arrives at the next).
  List<StopEvent> onFix({required double lat, required double lon, required DateTime at, double? speedMps}) {
    if (_phase == TripPhase.completed) {
      return const [];
    }

    if (_phase == TripPhase.notStarted) {
      final origin = stops.first;
      final withinWindow = at.isAfter(scheduledDeparture.subtract(departureWindow)) &&
          at.isBefore(scheduledDeparture.add(departureWindow));
      final atOrigin = withinGeofence(lat: lat, lon: lon, centerLat: origin.lat, centerLon: origin.lon, radiusM: origin.geofenceRadiusM);
      if (withinWindow && atOrigin) {
        _phase = TripPhase.inProgress;
        _liveMatcher.reset();
      } else {
        return const [];
      }
    }

    final match = _liveMatcher.match(lat, lon);
    _lastMatchedDistTraveled = match.distTraveled;
    final events = <StopEvent>[];

    while (_currentStopIndex < stops.length) {
      final target = stops[_currentStopIndex];
      final targetDist = _stopDistTraveled[_currentStopIndex];
      final inGeofence = withinGeofence(lat: lat, lon: lon, centerLat: target.lat, centerLon: target.lon, radiusM: target.geofenceRadiusM);

      if (inGeofence) {
        _dwellStart ??= at;
        if (!_incomingEmitted) {
          _incomingEmitted = true;
          events.add(StopEvent(stopId: target.stopId, stopSequence: target.sequence, status: VehicleStopStatus.incomingAt, at: at));
        }
        if (!_stoppedEmitted && at.difference(_dwellStart!) >= dwellThreshold) {
          _stoppedEmitted = true;
          events.add(StopEvent(
            stopId: target.stopId,
            stopSequence: target.sequence,
            status: VehicleStopStatus.stoppedAt,
            at: at,
            arrivedAt: _dwellStart,
          ));
          // The terminus auto-ends the trip on dwell, not on "leaving" — a
          // vehicle that parks at the terminus and stops sending fixes must
          // still end the duty (brief: "auto-end at the terminus geofence
          // with dwell").
          if (_currentStopIndex == stops.length - 1) {
            _phase = TripPhase.completed;
          }
        }
        // Still at (or approaching) this stop — nothing further to advance
        // this fix.
        break;
      }

      final pastByFar = match.distTraveled - targetDist >= skipAheadToleranceM;
      final leftAfterDwell = _dwellStart != null;
      if (!leftAfterDwell && !pastByFar) {
        // Haven't reached this stop's geofence yet and haven't skipped past
        // it either — nothing to do until a later fix.
        break;
      }

      // Departing this stop (whether we dwelled there or skipped it).
      final isTerminus = _currentStopIndex == stops.length - 1;
      final nextIndex = _currentStopIndex + 1;
      if (!isTerminus) {
        events.add(StopEvent(
          stopId: stops[nextIndex].stopId,
          stopSequence: stops[nextIndex].sequence,
          status: VehicleStopStatus.inTransitTo,
          at: at,
          departedAt: at,
        ));
      } else {
        _phase = TripPhase.completed;
      }

      _currentStopIndex = nextIndex;
      _dwellStart = null;
      _incomingEmitted = false;
      _stoppedEmitted = false;

      if (_phase == TripPhase.completed) {
        break;
      }
    }

    return events;
  }

  /// Ends the trip early — the manual override path (brief: "Manual
  /// override is available but should be rare").
  void endManually() {
    _phase = TripPhase.completed;
  }
}
