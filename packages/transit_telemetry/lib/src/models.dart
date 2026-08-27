/// A raw location fix as reported by the platform location plugin, before
/// any validation or smoothing.
class GeoFix {
  const GeoFix({
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
  });

  final double lat;
  final double lon;
  final DateTime timestamp;

  /// Horizontal accuracy in metres, when the platform reports one.
  final double? accuracyM;

  /// Ground speed in metres/second, when the platform reports one.
  final double? speedMps;

  /// Heading in degrees from true north, when the platform reports one.
  final double? headingDeg;
}

/// GTFS-RT `OccupancyStatus` enum values (a subset commonly settable from a
/// one-tap driver control) — kept here rather than invented ad hoc so the
/// ping payload matches the spec the exporter (Phase 10) will publish.
enum OccupancyStatus {
  empty(0),
  manySeatsAvailable(1),
  fewSeatsAvailable(2),
  standingRoomOnly(3),
  crushedStandingRoomOnly(4),
  full(5),
  notAcceptingPassengers(6);

  const OccupancyStatus(this.value);
  final int value;
}

/// One cleaned, ready-to-send ping — the payload shape `POST /driver/pings`
/// expects (see services/api/internal/httpapi/handlers/driver.go).
class PingRecord {
  const PingRecord({
    required this.assignmentId,
    required this.ts,
    required this.lat,
    required this.lon,
    this.heading,
    this.speed,
    this.accuracyM,
    this.occupancy,
    this.matchedShapeDist,
  });

  final String assignmentId;
  final DateTime ts;
  final double lat;
  final double lon;
  final double? heading;
  final double? speed;
  final double? accuracyM;
  final int? occupancy;
  final double? matchedShapeDist;

  Map<String, dynamic> toJson() => {
        'assignment_id': assignmentId,
        'ts': ts.toUtc().toIso8601String(),
        'lat': lat,
        'lon': lon,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (occupancy != null) 'occupancy': occupancy,
        if (matchedShapeDist != null) 'matched_shape_dist': matchedShapeDist,
      };

  factory PingRecord.fromJson(Map<String, dynamic> json) => PingRecord(
        assignmentId: json['assignment_id'] as String,
        ts: DateTime.parse(json['ts'] as String),
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        occupancy: json['occupancy'] as int?,
        matchedShapeDist: (json['matched_shape_dist'] as num?)?.toDouble(),
      );
}

/// A point on a trip shape, in GTFS shape order.
class ShapePoint {
  const ShapePoint({required this.lat, required this.lon, required this.distTraveled});

  final double lat;
  final double lon;

  /// Cumulative distance (metres) from the first shape point — GTFS
  /// `shape_dist_traveled` if the feed provides it, otherwise computed by
  /// [ShapeMatcher.fromPoints].
  final double distTraveled;
}

/// A stop on a trip, in stop_sequence order, with its geofence radius.
class TripStop {
  const TripStop({
    required this.stopId,
    required this.sequence,
    required this.lat,
    required this.lon,
    required this.geofenceRadiusM,
  });

  final String stopId;
  final int sequence;
  final double lat;
  final double lon;
  final double geofenceRadiusM;
}

/// GTFS-RT `VehiclePosition.current_status` enum — the vocabulary the brief
/// requires reusing rather than inventing a parallel one (§4.2).
enum VehicleStopStatus { incomingAt, stoppedAt, inTransitTo }

/// One stop arrival/departure/progression event the trip tracker emits.
class StopEvent {
  const StopEvent({
    required this.stopId,
    required this.stopSequence,
    required this.status,
    required this.at,
    this.arrivedAt,
    this.departedAt,
  });

  final String stopId;
  final int stopSequence;
  final VehicleStopStatus status;
  final DateTime at;
  final DateTime? arrivedAt;
  final DateTime? departedAt;
}
