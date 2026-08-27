import 'geo_math.dart';
import 'models.dart';

/// Rejects GPS fixes with poor accuracy, impossible speed, or a teleport
/// jump from the last accepted fix (brief §4.2 "Signal quality"). This is
/// the single most common bug in homemade AVL — a plain nearest-stop check
/// with no plausibility filter — so every fix goes through this before
/// anything else touches it.
class FixValidator {
  FixValidator({
    this.maxAccuracyM = 75.0,
    this.maxPlausibleSpeedMps = 55.0, // ~198 km/h — generous ceiling for any road vehicle
    this.maxTeleportSpeedMps = 70.0,
  });

  /// Fixes reported with worse (larger) accuracy than this are rejected
  /// outright — the device doesn't know where it is closely enough to trust.
  final double maxAccuracyM;

  /// Fixes whose own reported speed exceeds this are rejected.
  final double maxPlausibleSpeedMps;

  /// Fixes whose implied speed from the last accepted fix (distance / time)
  /// exceeds this are rejected as a teleport — a common symptom of a bad GPS
  /// fix in a tunnel or urban canyon suddenly "snapping" far away.
  final double maxTeleportSpeedMps;

  GeoFix? _lastAccepted;

  /// Returns the fix if it passes every check, or null if it should be
  /// dropped. Accepting a fix updates the last-accepted reference used for
  /// the next teleport check.
  GeoFix? accept(GeoFix fix) {
    if (fix.accuracyM != null && fix.accuracyM! > maxAccuracyM) {
      return null;
    }
    if (fix.speedMps != null && fix.speedMps! > maxPlausibleSpeedMps) {
      return null;
    }

    final last = _lastAccepted;
    if (last != null) {
      final dtSeconds = fix.timestamp.difference(last.timestamp).inMilliseconds / 1000.0;
      if (dtSeconds > 0) {
        final distanceM = haversineMeters(last.lat, last.lon, fix.lat, fix.lon);
        final impliedSpeed = distanceM / dtSeconds;
        if (impliedSpeed > maxTeleportSpeedMps) {
          return null;
        }
      } else if (dtSeconds < 0) {
        // Out-of-order fix (clock skew or replay) — never accept, it would
        // corrupt monotonic shape progression downstream.
        return null;
      }
    }

    _lastAccepted = fix;
    return fix;
  }

  /// Resets teleport-detection state — call this when a new trip/duty
  /// starts so a stale reference from the previous trip never rejects the
  /// first fix of a new one.
  void reset() {
    _lastAccepted = null;
  }
}
