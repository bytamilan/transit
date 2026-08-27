/// A scalar Kalman filter over GPS position, in the spirit of the classic
/// "SimpleKalmanFilter for GPS" technique: a single variance (in metres²,
/// since a GPS accuracy circle is isotropic) drives a unitless gain that
/// blends each new fix into the running estimate. The gain is dimensionless,
/// so it can weight the lat/lon delta directly even though the tracked
/// variance is in metres — no unit conversion needed per update.
///
/// This exists to turn a jittery raw GPS trace into a smooth one before it
/// ever reaches shape-matching or geofencing — an unsmoothed trace makes a
/// vehicle appear to jitter across the road and can flip stop-arrival
/// geofences on and off spuriously.
class GeoKalmanFilter {
  GeoKalmanFilter({this.processNoisePerSecond = 3.0});

  /// How fast position uncertainty grows per second without a new fix
  /// (metres² per second). Larger values trust new fixes more; smaller
  /// values smooth more aggressively at the cost of lag.
  final double processNoisePerSecond;

  double? _estLat;
  double? _estLon;
  double? _variance;
  DateTime? _lastUpdate;

  /// Feeds one fix through the filter and returns the smoothed (lat, lon).
  /// `accuracyM` is the fix's reported horizontal accuracy; when null, a
  /// conservative default is assumed so a single unreliable fix can't yank
  /// the estimate.
  ({double lat, double lon}) update({
    required double lat,
    required double lon,
    required DateTime timestamp,
    double? accuracyM,
  }) {
    final measurementVariance = _measurementVariance(accuracyM);

    if (_estLat == null || _estLon == null || _variance == null || _lastUpdate == null) {
      _estLat = lat;
      _estLon = lon;
      _variance = measurementVariance;
      _lastUpdate = timestamp;
      return (lat: lat, lon: lon);
    }

    final dtSeconds = timestamp.difference(_lastUpdate!).inMilliseconds / 1000.0;
    // A fix from before the last one (or the same instant) still gets
    // filtered, just without additional process-noise growth.
    final predictedVariance = _variance! + processNoisePerSecond * (dtSeconds > 0 ? dtSeconds : 0);

    final gain = predictedVariance / (predictedVariance + measurementVariance);
    _estLat = _estLat! + gain * (lat - _estLat!);
    _estLon = _estLon! + gain * (lon - _estLon!);
    _variance = (1 - gain) * predictedVariance;
    _lastUpdate = timestamp;

    return (lat: _estLat!, lon: _estLon!);
  }

  /// Resets filter state — call at the start of a new trip so the previous
  /// trip's terminus doesn't bias the new trip's first estimate.
  void reset() {
    _estLat = null;
    _estLon = null;
    _variance = null;
    _lastUpdate = null;
  }

  double _measurementVariance(double? accuracyM) {
    final a = accuracyM ?? 30.0;
    return a * a;
  }
}
