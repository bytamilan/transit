/// Decides how often to sample GPS while moving vs. idle, and bursts near
/// stops — brief §4.2 "Adaptive sampling". Driven entirely by the agency's
/// `driver_ops` config (never hardcoded), so every deployment can tune it.
class AdaptiveSampler {
  AdaptiveSampler({
    required this.movingIntervalSeconds,
    required this.idleIntervalSeconds,
    this.idleSpeedThresholdMps = 0.5,
    this.nearStopRadiusM = 150.0,
    this.nearStopIntervalSeconds = 2,
  });

  final int movingIntervalSeconds;
  final int idleIntervalSeconds;

  /// Speed below which the vehicle is considered idle rather than moving.
  final double idleSpeedThresholdMps;

  /// Within this distance of the next stop, sample at [nearStopIntervalSeconds]
  /// regardless of moving/idle — this is what keeps arrival/departure
  /// detection tight without polling fast for the whole trip.
  final double nearStopRadiusM;
  final int nearStopIntervalSeconds;

  /// Returns the sampling interval to use for the *next* fix, given the
  /// current speed and distance to the next stop (null when unknown, e.g.
  /// before the trip has started map-matching).
  Duration intervalFor({required double? speedMps, double? distanceToNextStopM}) {
    if (distanceToNextStopM != null && distanceToNextStopM <= nearStopRadiusM) {
      return Duration(seconds: nearStopIntervalSeconds);
    }
    final moving = speedMps != null && speedMps > idleSpeedThresholdMps;
    return Duration(seconds: moving ? movingIntervalSeconds : idleIntervalSeconds);
  }
}
