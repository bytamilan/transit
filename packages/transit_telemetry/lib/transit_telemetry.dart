/// On-device tracking primitives for the driver app: adaptive sampling, GPS
/// smoothing, junk-fix rejection, shape map-matching, stop/trip detection
/// and a persistent offline ping queue. See build brief §4.2 — the server
/// (Phase 8) recomputes everything from the raw trace; nothing this package
/// produces is trusted as authoritative.
library transit_telemetry;

export 'src/adaptive_sampler.dart';
export 'src/fix_validator.dart';
export 'src/geo_math.dart';
export 'src/geofence.dart';
export 'src/kalman_filter.dart';
export 'src/models.dart';
export 'src/ping_queue.dart';
export 'src/shape_matcher.dart';
export 'src/telemetry_engine.dart';
export 'src/trip_tracker.dart';
